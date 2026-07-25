import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/services/session_service.dart';
import 'chat_model.dart';

class ChatRepository {
  final _api = Get.find<ApiService>();
  final _cache = CacheService();

  int get _myId => Get.find<SessionService>().user.value?.id ?? 0;

  Future<List<Conversation>> inbox() async {
    final res = await _api.get('/chats/getAllChats', queryParameters: {'limit': 100});
    final data = unwrapData(res);
    await _cache.put('chat_inbox', jsonEncode(data));
    return Paged.fromJson(data, Conversation.fromJson).list;
  }

  List<Conversation>? cachedInbox() {
    final raw = _cache.get<String>('chat_inbox');
    if (raw == null) return null;
    try {
      return Paged.fromJson(jsonDecode(raw), Conversation.fromJson).list;
    } catch (_) {
      return null;
    }
  }

  // opens (or creates) the conversation with a user; also returns post context
  Future<(Conversation, ChatPostContext?, ChatDealRef?)> details(int receiverId,
      {int? postId}) async {
    final res = await _api.get(
      '/chats/getChatDetails/$receiverId',
      queryParameters: postId != null ? {'postId': postId} : null,
    );
    final data = Map<String, dynamic>.from(unwrapData(res));
    final conv = Conversation(
      chatId: data['chat']?['id'] ?? 0,
      user: Conversation.fromJson({'user': data['user']}).user,
      lastMessage: data['chat']?['lastMessage'] ?? '',
      unread: data['chat']?['newMessages'] ?? 0,
    );
    return (
      conv,
      ChatPostContext.fromJson(data['post']),
      ChatDealRef.fromJson(data['deal']),
    );
  }

  Future<List<ChatMessage>> messages(int chatId) async {
    final res = await _api.get('/chats/getChatMessages/$chatId',
        queryParameters: {'limit': 100});
    final data = unwrapData(res);
    final raw = data is Map ? (data['list'] ?? []) : (data ?? []);
    // API returns newest-first; flip to oldest→newest so the conversation
    // reads top-to-bottom and live socket messages append at the end
    return (raw as List)
        .whereType<Map>()
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e), _myId))
        .toList()
        .reversed
        .toList();
  }

  // message or attachment (or both) — the API needs at least one
  Future<void> send(
    int chatId, {
    String message = '',
    String? filePath,
    String? fileName,
  }) async {
    final form = FormData.fromMap({
      if (message.isNotEmpty) 'message': message,
      if (filePath != null)
        'attachFile': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    unwrapData(await _api.post('/chats/sendMessage/$chatId', data: form));
  }
}
