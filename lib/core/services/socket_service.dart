import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../constants/api_constants.dart';
import 'api_envelope.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'realtime_config.dart';
import 'data_bus.dart';
import 'location_tracker_service.dart';
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

  // Pusher key / cluster / auth URL come from the server (`/realtime-config`)
  // — the built-in values in [RealtimeConfig.fallback] are the last resort.
  static const _configCacheKey = 'realtime_config';
  RealtimeConfig _config = RealtimeConfig.fallback;
  bool _configFromServer = false;
  RealtimeConfig get config => _config;

  final _pusher = PusherChannelsFlutter.getInstance();
  bool _inited = false;
  bool _connected = false;
  final _rooms = <String>{};

  final _chatList = StreamController<Map<String, dynamic>>.broadcast();
  final _messages = StreamController<SocketMessage>.broadcast();
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  final _dealEvents = StreamController<Map<String, dynamic>>.broadcast();
  final _locations = StreamController<Map<String, dynamic>>.broadcast();
  final _trackingStopped = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get chatListUpdates => _chatList.stream;
  Stream<SocketMessage> get messages => _messages.stream;
  Stream<Map<String, dynamic>> get notificationEvents => _notifications.stream;
  Stream<Map<String, dynamic>> get dealEvents => _dealEvents.stream;
  /// Track My Order: `.deal.location.updated` on `private-deal.{id}` —
  /// `{dealId, latitude, longitude, heading, connectionStatus, recordedAt}`.
  Stream<Map<String, dynamic>> get locationUpdates => _locations.stream;
  /// Track My Order: `deal.tracking.stopped` on `private-deal.{id}` —
  /// `{dealId, dealStatus, reason, stoppedAt}`.
  Stream<Map<String, dynamic>> get trackingStopped => _trackingStopped.stream;

  // the server's authEndpoint; else /broadcasting/auth at the host root
  // (not under /api/v1)
  String get _authUrl =>
      _config.authEndpoint ??
      '${ApiConstants.baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '')}/broadcasting/auth';

  /// `GET /realtime-config` (needs login). Offline → the config saved from
  /// the last login → the built-in fallback.
  Future<void> loadConfig() async {
    try {
      final data = unwrapData(await ApiService().get('/realtime-config'));
      final cfg = RealtimeConfig.tryParse(data);
      if (cfg != null) {
        await applyConfig(cfg);
        return;
      }
    } catch (e) {
      if (kDebugMode) print('socket: realtime-config failed $e');
    }
    if (_configFromServer) return;
    try {
      final raw = CacheService().get<String>(_configCacheKey);
      final saved = raw == null ? null : RealtimeConfig.tryParse(jsonDecode(raw));
      if (saved != null) _config = saved;
    } catch (_) {}
  }

  /// A config from the server (`/realtime-config`, or the `realtime` block in
  /// the tracking responses). Saved for offline launches; a changed key or
  /// cluster restarts the socket, and a disabled one closes it (→ polling).
  Future<void> applyConfig(RealtimeConfig cfg) async {
    final changed = !cfg.sameConnection(_config);
    _config = cfg;
    _configFromServer = true;
    try {
      await CacheService().put(_configCacheKey, jsonEncode(cfg.toJson()));
    } catch (_) {}
    if (!changed || !_inited) return;
    _inited = false;
    if (_connected) {
      _connected = false;
      try {
        await _pusher.disconnect();
      } catch (_) {}
    }
    if (cfg.usable) await _connect();
  }

  // the shell and the chat inbox both call connect() at start-up
  Future<void>? _connecting;

  Future<void> connect() {
    if (_connecting != null) return _connecting!;
    final f = _connect();
    _connecting = f;
    return f.whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    final myId = _session.user.value?.id;
    if (myId == null || _connected) return;
    if (!_configFromServer) await loadConfig();
    if (_connected) return; // applyConfig may have connected meanwhile
    // server says no Pusher here (or a self-hosted socket the plugin can't
    // reach): screens fall back to polling
    if (!_config.usable) return;

    try {
      if (!_inited) {
        // authEndpoint is NOT passed: on iOS it would replace onAuthorizer,
        // which carries the bearer token
        await _pusher.init(
          apiKey: _config.key,
          cluster: _config.cluster,
          useTLS: _config.useTLS,
          onAuthorizer: _authorize,
          onEvent: _onEvent,
          onConnectionStateChange: (current, previous) {
            if (kDebugMode) print('socket: $previous → $current');
            // lets connect() bring a dropped socket back instead of
            // believing it is still up
            if (current.toUpperCase() == 'DISCONNECTED') _connected = false;
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
      // already-subscribed channels throw on a reconnect — that's fine
      // own channels, plus rooms/deals screens still hold (after a restart
      // for a new config the native client has none of them)
      for (final ch in ['private-chats.$myId', 'private-notifications.$myId', ..._rooms]) {
        try {
          await _pusher.subscribe(channelName: ch);
        } catch (_) {}
      }
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
    } else if (name.contains('tracking.stopped') ||
        _isEvent(name, _config.stoppedEvent) ||
        name.endsWith('DealTrackingStopped')) {
      final m = RegExp(r'(\d+)$').firstMatch(event.channelName);
      final id = int.tryParse('${payload['dealId'] ?? payload['deal_id'] ?? m?.group(1) ?? ''}');
      _trackingStopped.add({...payload, 'dealId': id});
      // transporter side: end the GPS service now, not on the next refresh
      if (id != null && Get.isRegistered<LocationTrackerService>()) {
        Get.find<LocationTrackerService>().stop(id);
      }
      DataBus.changed(DataTopic.deals);
    } else if (name.contains('location.updated') ||
        _isEvent(name, _config.locationEvent) ||
        name.endsWith('DealLocationUpdated')) {
      // a moving pin, not a state change — must not reload every deal list
      final m = RegExp(r'(\d+)$').firstMatch(event.channelName);
      _locations.add({
        ...payload,
        'dealId': payload['dealId'] ?? (m == null ? null : int.tryParse(m.group(1)!)),
      });
    } else if (name.contains('deal.status.updated') ||
        name.endsWith('DealStatusUpdated') ||
        event.channelName.startsWith('private-deal.') ||
        event.channelName.startsWith(_config.channelPrefix)) {
      // Echo may prefix the name (".deal.status.updated" or the class name)
      _dealEvents.add(payload);
      // deal lists and the wallet everywhere reload, not just the open deal
      DataBus.changed(DataTopic.deals);
    } else if (event.channelName.startsWith('private-notifications.')) {
      _notifications.add(payload);
      // most notifications are deal/payment updates for the other side
      DataBus.changed(DataTopic.deals);
    }
  }

  // plain Pusher gets the exact name; Echo-style senders prefix a dot
  bool _isEvent(String name, String wanted) =>
      wanted.isNotEmpty && (name == wanted || name.endsWith('.$wanted'));

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

  // the deal page and Track My Order can both hold the same deal channel;
  // it only goes when the last of them leaves
  final _dealRefs = <int, int>{};

  Future<void> subscribeDeal(int dealId) async {
    _dealRefs[dealId] = (_dealRefs[dealId] ?? 0) + 1;
    if (!_connected) await connect();
    if (!_connected) return;
    final ch = '${_config.channelPrefix}$dealId';
    if (!_rooms.add(ch)) return;
    try {
      await _pusher.subscribe(channelName: ch);
    } catch (_) {
      _rooms.remove(ch);
    }
  }

  Future<void> leaveDeal(int dealId) async {
    final left = (_dealRefs[dealId] ?? 1) - 1;
    if (left > 0) {
      _dealRefs[dealId] = left;
      return;
    }
    _dealRefs.remove(dealId);
    final ch = '${_config.channelPrefix}$dealId';
    if (!_rooms.remove(ch)) return;
    try {
      await _pusher.unsubscribe(channelName: ch);
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _rooms.clear();
    _dealRefs.clear();
    // the next login asks /realtime-config again
    _configFromServer = false;
    if (!_connected) return;
    _connected = false;
    try {
      await _pusher.disconnect();
    } catch (_) {}
  }
}
