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
import 'chat_inbox_controller.dart';

// One controller per open conversation. Live messages arrive over the
// chatRoom Pusher channel; a slow poll reconciles in case the socket drops.
class ChatConversationController extends GetxController {
  final PostUser peer;
  final int? initialChatId;
  int? postId; // set when the chat was opened from a post

  ChatConversationController({required this.peer, this.initialChatId, this.postId});

  final messages = <ChatMessage>[].obs;
  final loading = true.obs;
  final sending = false.obs;
  final post = Rxn<ChatPostContext>();
  // non-null once an agreement exists for this chat
  final deal = Rxn<ChatDealRef>();
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
      final (conv, ctx, dealRef) = await _repo.details(peer.id, postId: postId);
      _chatId = (initialChatId != null && initialChatId != 0) ? initialChatId : conv.chatId;
      post.value = ctx;
      deal.value = dealRef;

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

  // The same conversation can be reopened from a different post — e.g. the
  // other side comes back with a trip after the first deal closed. The website
  // does this by setting selectedPostId and re-reading chat details; the server
  // then swaps the chat's post (and drops a closed deal on a different post),
  // so the route strip and the sender/traveler roles recompute.
  Future<void> switchPost(int? newPostId) async {
    if (postId == newPostId) return;
    postId = newPostId;
    await reloadContext();
  }

  // re-reads post/deal so the action bar flips to "View agreement" the moment
  // one is confirmed, instead of going stale until the screen is reopened
  Future<void> reloadContext() async {
    try {
      final (_, ctx, dealRef) = await _repo.details(peer.id, postId: postId);
      post.value = ctx;
      deal.value = dealRef;
    } on AppException catch (_) {
      // leave the current bar in place — the next open re-reads it
    }
  }

  // keep the inbox (if it's alive) from flagging our own message as unread
  void _notifyInbox(int chatId, String preview) {
    if (Get.isRegistered<ChatInboxController>()) {
      Get.find<ChatInboxController>().markSelfSent(chatId, preview);
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
      _notifyInbox(id, text);
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
      _notifyInbox(id, '📎 ${file.name}');
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
