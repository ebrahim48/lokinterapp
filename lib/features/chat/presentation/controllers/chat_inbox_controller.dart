import 'dart:async';

import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/services/socket_service.dart';
import '../../data/chat_model.dart';
import '../../data/chat_repository.dart';

class ChatInboxController extends GetxController {
  final conversations = <Conversation>[].obs;
  final loading = true.obs;
  final error = RxnString();

  final _repo = ChatRepository();
  final _socket = Get.find<SocketService>();
  StreamSubscription<Map<String, dynamic>>? _sub;

  // chats we just sent to — the server echoes our own message back on this
  // channel with a phantom unread count, so suppress it briefly
  final _selfSent = <int, DateTime>{};

  @override
  void onInit() {
    super.onInit();
    load();
    _socket.connect();
    // any chat gaining a message re-sorts to the top with a fresh preview
    _sub = _socket.chatListUpdates.listen(_onListEvent);
  }

  Future<void> load() async {
    final cached = _repo.cachedInbox();
    if (cached != null) {
      conversations.assignAll(cached);
      loading.value = false;
    }
    try {
      conversations.assignAll(await _repo.inbox());
      error.value = null;
    } on AppException catch (e) {
      if (conversations.isEmpty) error.value = e.message;
    } finally {
      loading.value = false;
    }
  }

  // called when the current user sends into a chat, so the echoed-back list
  // event doesn't render our own message as an unread incoming one
  void markSelfSent(int chatId, String preview) {
    _selfSent[chatId] = DateTime.now();
    final i = conversations.indexWhere((c) => c.chatId == chatId);
    if (i != -1) {
      final updated = conversations[i].copyWith(lastMessage: preview, unread: 0);
      conversations
        ..removeAt(i)
        ..insert(0, updated);
    }
  }

  void _onListEvent(Map<String, dynamic> payload) {
    var conv = Conversation.fromJson(payload);
    if (conv.chatId == 0) return;
    // the first list event right after we send is our own message echoed back —
    // drop its phantom unread, but consume the marker so a later genuine reply
    // still counts
    final sentAt = _selfSent.remove(conv.chatId);
    if (sentAt != null && DateTime.now().difference(sentAt) < const Duration(seconds: 10)) {
      conv = conv.copyWith(unread: 0);
    }
    conversations
      ..removeWhere((c) => c.chatId == conv.chatId)
      ..insert(0, conv);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
