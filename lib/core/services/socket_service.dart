import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../constants/api_constants.dart';
import 'session_service.dart';

// A live chat message pushed on a chatRoom channel, tagged with which chat it
// belongs to (the payload itself doesn't carry the chat id — the channel does).
class SocketMessage {
  final int chatId;
  final Map<String, dynamic> data;
  const SocketMessage(this.chatId, this.data);
}

// Real-time layer over Pusher Channels — mirrors the Laravel Echo setup:
//   private-chats.{me}         → .chats.list      (inbox badge + previews)
//   private-chatRoom.{chatId}  → .chats.messages  (live messages in a room)
//   private-notifications.{me} → notification events
// Auth goes through POST /broadcasting/auth with the Sanctum bearer token.
class SocketService extends GetxService {
  final SessionService _session;
  SocketService(this._session);

  static const _appKey = '6be7243295ab894483a1';
  static const _cluster = 'ap1';

  final _pusher = PusherChannelsFlutter.getInstance();
  bool _inited = false;
  bool _connected = false;
  final _rooms = <String>{};

  final _chatList = StreamController<Map<String, dynamic>>.broadcast();
  final _messages = StreamController<SocketMessage>.broadcast();
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get chatListUpdates => _chatList.stream;
  Stream<SocketMessage> get messages => _messages.stream;
  Stream<Map<String, dynamic>> get notificationEvents => _notifications.stream;

  // /broadcasting/auth sits at the host root, not under /api/v1
  String get _authUrl =>
      '${ApiConstants.baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '')}/broadcasting/auth';

  Future<void> connect() async {
    final myId = _session.user.value?.id;
    if (myId == null || _connected) return;

    try {
      if (!_inited) {
        await _pusher.init(
          apiKey: _appKey,
          cluster: _cluster,
          onAuthorizer: _authorize,
          onEvent: _onEvent,
          onConnectionStateChange: (current, previous) {
            if (kDebugMode) print('socket: $previous → $current');
          },
          onSubscriptionSucceeded: (channel, data) {
            if (kDebugMode) print('socket: subscribed $channel');
          },
          onSubscriptionError: (message, e) {
            if (kDebugMode) print('socket: subscribe error $message');
          },
          onError: (message, code, e) {
            if (kDebugMode) print('socket: error $message ($code)');
          },
        );
        _inited = true;
      }
      await _pusher.connect();
      _connected = true;
      await _pusher.subscribe(channelName: 'private-chats.$myId');
      await _pusher.subscribe(channelName: 'private-notifications.$myId');
    } catch (e) {
      // chat still works over REST polling if the socket can't come up
      _connected = false;
      if (kDebugMode) print('socket connect failed: $e');
    }
  }

  Future<dynamic> _authorize(String channelName, String socketId, dynamic options) async {
    // The native plugin (fetchAuthValue) does `authData as! [String:String]`
    // then `["auth"]!` when this returns non-null, but calls back gracefully
    // when it returns null. So return a Map ONLY with a valid string `auth`,
    // otherwise return null — never throw, never a partial map, or iOS aborts
    // (dynamic-cast failure / nil-unwrap).
    try {
      final res = await Dio().post(
        _authUrl,
        data: {'socket_id': socketId, 'channel_name': channelName},
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_session.accessToken}',
            'Accept': 'application/json',
          },
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      var data = res.data; // { "auth": "key:signature", ... }
      if (data is String && data.isNotEmpty) data = jsonDecode(data);
      if (data is Map && data['auth'] is String) {
        // native casts to [String:String] — stringify, drop null-valued keys
        return {
          for (final e in data.entries)
            if (e.value != null) '${e.key}': '${e.value}',
        };
      }
      return null;
    } catch (e) {
      // fail the subscription cleanly (onSubscriptionError) instead of crashing
      if (kDebugMode) print('socket auth failed: $e');
      return null;
    }
  }

  void _onEvent(PusherEvent event) {
    final name = event.eventName;
    if (name.startsWith('pusher:') || name.startsWith('pusher_internal:')) return;

    Map<String, dynamic>? payload;
    try {
      final raw = event.data;
      if (raw is String && raw.isNotEmpty) {
        payload = Map<String, dynamic>.from(jsonDecode(raw));
      } else if (raw is Map) {
        payload = Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    if (payload == null) return;

    if (name == 'chats.list') {
      _chatList.add(payload);
    } else if (name == 'chats.messages') {
      final chatId = _chatIdFrom(event.channelName);
      if (chatId != null) _messages.add(SocketMessage(chatId, payload));
    } else if (event.channelName.startsWith('private-notifications.')) {
      _notifications.add(payload);
    }
  }

  int? _chatIdFrom(String channel) {
    final m = RegExp(r'chatRoom\.(\d+)').firstMatch(channel);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  Future<void> subscribeRoom(int chatId) async {
    if (!_connected) await connect();
    if (!_connected) return;
    final ch = 'private-chatRoom.$chatId';
    if (!_rooms.add(ch)) return;
    try {
      await _pusher.subscribe(channelName: ch);
    } catch (_) {
      _rooms.remove(ch);
    }
  }

  Future<void> leaveRoom(int chatId) async {
    final ch = 'private-chatRoom.$chatId';
    if (!_rooms.remove(ch)) return;
    try {
      await _pusher.unsubscribe(channelName: ch);
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _rooms.clear();
    if (!_connected) return;
    _connected = false;
    try {
      await _pusher.disconnect();
    } catch (_) {}
  }
}
