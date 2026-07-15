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

  void _onListEvent(Map<String, dynamic> payload) {
    final conv = Conversation.fromJson(payload);
    if (conv.chatId == 0) return;
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
