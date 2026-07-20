import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/utils/notify.dart';
import '../../../posts/data/models/post_model.dart';
import '../../data/chat_model.dart';
import '../../data/chat_repository.dart';

// One controller per open conversation. Live messages arrive over the
// chatRoom Pusher channel; a slow poll reconciles in case the socket drops.
class ChatConversationController extends GetxController {
  final PostUser peer;
  final int? initialChatId;
  final int? postId; // set when the chat was opened from a post

  ChatConversationController({required this.peer, this.initialChatId, this.postId});

  final messages = <ChatMessage>[].obs;
  final loading = true.obs;
  final sending = false.obs;
  final post = Rxn<ChatPostContext>();
  final composer = TextEditingController();

  int? _chatId;
  Timer? _poll;
  StreamSubscription<SocketMessage>? _sub;
  final _repo = ChatRepository();
  final _socket = Get.find<SocketService>();
  final _myId = Get.find<SessionService>().user.value?.id ?? 0;

  int? get chatId => _chatId;

  @override
  void onInit() {
    super.onInit();
    _open();
  }

  Future<void> _open() async {
    try {
      final (conv, ctx) = await _repo.details(peer.id, postId: postId);
      _chatId = (initialChatId != null && initialChatId != 0) ? initialChatId : conv.chatId;
      post.value = ctx;

      await _refresh();

      final id = _chatId;
      if (id != null) {
        await _socket.subscribeRoom(id);
        _sub = _socket.messages
            .where((m) => m.chatId == id)
            .listen(_onSocketMessage);
      }
      // safety net — the socket is primary, this just heals missed frames
      _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
    } on AppException catch (e) {
      toastError(e);
    } finally {
      loading.value = false;
    }
  }

  void _onSocketMessage(SocketMessage m) {
    final msg = ChatMessage.fromJson(m.data, _myId);
    if (msg.id != 0 && messages.any((x) => x.id == msg.id)) return; // already have it
    messages.add(msg);
  }

  Future<void> _refresh() async {
    final id = _chatId;
    if (id == null) return;
    try {
      messages.assignAll(await _repo.messages(id));
    } on AppException catch (_) {
      // polling failures stay quiet — the next tick or socket frame recovers
    }
  }

  Future<void> send() async {
    final id = _chatId;
    final text = composer.text.trim();
    if (sending.value) return;
    if (id == null) {
      toast('Conversation is still opening — try again in a moment');
      return;
    }
    if (text.isEmpty) return; // nothing to send, no need to nag
    sending.value = true;
    try {
      await _repo.send(id, message: text);
      composer.clear();
      await _refresh(); // the sender is excluded from the socket broadcast
    } on AppException catch (e) {
      toastError(e);
    } finally {
      sending.value = false;
    }
  }

  // any file type, capped at the API's 200 MB limit
  Future<void> sendAttachment() async {
    final id = _chatId;
    if (id == null || sending.value) return;

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles();
    } on Exception catch (_) {
      toast('Could not open the file picker');
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    if (file.path == null) return;
    if (file.size > 200 * 1024 * 1024) {
      toast('Attachments must be 200 MB or smaller');
      return;
    }

    sending.value = true;
    try {
      await _repo.send(id, filePath: file.path, fileName: file.name);
      await _refresh();
      toast('Attachment sent');
    } on AppException catch (e) {
      toastError(e);
    } finally {
      sending.value = false;
    }
  }

  @override
  void onClose() {
    _poll?.cancel();
    _sub?.cancel();
    if (_chatId != null) _socket.leaveRoom(_chatId!);
    composer.dispose();
    super.onClose();
  }
}
