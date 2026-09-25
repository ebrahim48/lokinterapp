import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart' hide Response;
import '../utils/push_router.dart';
import 'api_service.dart';
import 'data_bus.dart';
import 'session_service.dart';
import 'storage_service.dart';

/// Runs in its own isolate when a push lands with the app backgrounded or dead.
/// The tray entry is drawn by the system from the message's `notification`
/// block, so there is nothing to show here — but the isolate is cold, so
/// Firebase has to come up before the message can be read at all.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) print('push (background): ${message.messageId} ${message.data}');
}

/// Firebase Cloud Messaging, end to end:
///   • registers the device token with `/auth/fcm-token` while logged in
///   • draws the heads-up banner on Android when a push lands with the app open
///     (iOS does its own — see [_onForeground])
///   • routes a tap to the screen the payload points at ([openFromPush])
///
/// Firebase is configured from the native files (`google-services.json` /
/// `GoogleService-Info.plist`), not from a Dart options class — one source of
/// truth, and the same values the native SDKs read at launch.
class PushService extends GetxService {
  final SessionService _session;
  final StorageService _storage;
  PushService(this._session, this._storage);

  /// Must match `default_notification_channel_id` in AndroidManifest.xml, or a
  /// backgrounded push lands in a channel the user never sees.
  static const _channelId = 'high_importance_channel';
  static const _channelName = 'Deals, chat and payments';
  static const _channelDescription =
      'Deal updates, new messages, payments and verification results.';

  /// Resolved on use, not in the constructor: `FirebaseMessaging.instance`
  /// reaches for the default Firebase app and throws when there is none (no
  /// google-services.json / GoogleService-Info.plist). Every caller below sits
  /// behind [_ready], so it is only ever touched once Firebase is really up.
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  bool _ready = false; // false when Firebase failed to come up
  bool _coldStartHandled = false;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;

  ApiService get _api => Get.find<ApiService>();

  /// Brings the messaging layer up — no permission prompt and no token yet,
  /// those wait for [start] so a guest browsing the feed is never asked.
  /// Never throws: a missing google-services file must not stop the app.
  Future<PushService> init() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
      await _initLocalNotifications();
      _foreground = FirebaseMessaging.onMessage.listen(_onForeground);
      // tapped from the tray with the app alive but backgrounded
      _opened = FirebaseMessaging.onMessageOpenedApp.listen((m) => openFromPush(m.data));
      _ready = true;
    } catch (e) {
      if (kDebugMode) print('push init failed: $e');
    }
    return this;
  }

  /// Called once the user is inside the app: asks for permission, registers the
  /// token, and replays the notification that cold-started the app.
  Future<void> start() async {
    if (!_ready || !_session.loggedIn) return;
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return; // nothing worth registering — the OS will drop every push
      }

      // iOS draws the foreground banner itself; Android gets ours (see
      // _onForeground), so leaving both on would double up on iOS.
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await _currentToken();
      if (token != null) await _register(token);
      // the token rotates on reinstall, restore and app-data clears
      _tokenRefresh ??= _fcm.onTokenRefresh.listen(_register);

      if (!_coldStartHandled) {
        _coldStartHandled = true;
        final initial = await _fcm.getInitialMessage();
        if (initial != null) openFromPush(initial.data);
      }
    } catch (e) {
      if (kDebugMode) print('push start failed: $e');
    }
  }

  /// Drops the token server-side and locally so the next account on this phone
  /// doesn't inherit the last one's pushes. Must run while the bearer token is
  /// still valid — i.e. before [SessionService.clear].
  Future<void> stop() async {
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    if (!_ready) return;
    try {
      final token = _storage.getString(StorageKeys.fcmToken) ?? await _currentToken();
      if (token != null) {
        await _api.delete('/auth/fcm-token', data: {'fcmToken': token});
      }
      await _fcm.deleteToken();
    } catch (e) {
      // a dead token on the server is harmless — it gets pruned on first send
      if (kDebugMode) print('push unregister failed: $e');
    }
    await _storage.remove(StorageKeys.fcmToken);
  }

  // ─── token ────────────────────────────────────────────────────────────────

  /// iOS can't mint an FCM token until APNs has handed one over, which lands a
  /// beat after the permission prompt — so retry once instead of giving up.
  Future<String?> _currentToken() async {
    var token = await _fcm.getToken();
    if (token == null && Platform.isIOS) {
      await Future.delayed(const Duration(seconds: 3));
      token = await _fcm.getToken();
    }
    return token;
  }

  Future<void> _register(String token) async {
    try {
      await _api.post('/auth/fcm-token', data: {
        'fcmToken': token,
        'deviceType': Platform.isIOS ? 'ios' : 'android',
        'deviceId': await _deviceId(),
      });
      await _storage.setString(StorageKeys.fcmToken, token);
      if (kDebugMode) print('push token registered: ${token.substring(0, 12)}…');
    } catch (e) {
      // the next launch retries; pushes just don't arrive until then
      if (kDebugMode) print('push token registration failed: $e');
    }
  }

  /// Stable per install — the backend keys one token row per device, so this is
  /// what stops a reinstall from leaving a dead token behind.
  Future<String> _deviceId() async {
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) return (await info.androidInfo).id;
      if (Platform.isIOS) return (await info.iosInfo).identifierForVendor ?? 'ios';
    } catch (_) {}
    return 'unknown';
  }

  // ─── foreground banner ────────────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    // iOS permissions are asked for through FirebaseMessaging.requestPermission
    // in start(), so nothing here should prompt.
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          openFromPush(Map<String, dynamic>.from(jsonDecode(payload)));
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high, // heads-up, not a silent tray entry
          ));
    }
  }

  void _onForeground(RemoteMessage message) {
    if (kDebugMode) print('push (foreground): ${message.data}');
    // a push means something changed server-side — refresh what's on screen
    // now instead of waiting for the user to pull
    DataBus.changed(DataTopic.deals);
    DataBus.changed(DataTopic.wallet);
    // iOS presents it itself (setForegroundNotificationPresentationOptions);
    // showing a local copy there would give the user two banners.
    if (!Platform.isAndroid) return;

    // A data-only push carries no `notification` block, so the title and body
    // ride along in `data` instead — without this fallback those arrive silently.
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return; // nothing to put on screen

    _local.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          icon: 'ic_stat_notification',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  @override
  void onClose() {
    _foreground?.cancel();
    _opened?.cancel();
    _tokenRefresh?.cancel();
    super.onClose();
  }
}
