import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../features/deals/data/deal_model.dart';
import '../../features/deals/data/deals_repository.dart';
import '../../features/deals/data/tracking_models.dart';
import '../../features/deals/data/tracking_repository.dart';
import '../exceptions/app_exceptions.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';
import 'session_service.dart';

/// Where the transporter's location sharing stands — drives the banner on
/// the deal page (GUIDE Screen 7.3).
enum TrackerPermission { unknown, granted, foregroundOnly, denied, servicesOff }

/// Shares the transporter's GPS position while their local deals are ONGOING
/// (REQ §6.3 · GUIDE Screen 7).
///
/// * Starts only for a deal that is local, ONGOING and carried by this user —
///   i.e. once pickup evidence succeeded. Stops the moment the deal completes
///   or is cancelled, and releases the foreground service / wake lock.
/// * One position stream feeds every active deal (a transporter may carry
///   several parcels on one run), throttled to the server's interval.
/// * In a dead zone, fixes are buffered on disk and flushed as one `points`
///   batch on reconnect. Losing signal never touches the deal itself.
/// * On Android it runs as a location foreground service (the system shows an
///   ongoing notification); on iOS through background location updates. If
///   the OS kills the app, sharing resumes the next time it opens.
class LocationTrackerService extends GetxService {
  static const _defaultInterval = Duration(seconds: 20);
  static const _queuePrefix = 'tracking_queue_';
  static const _maxQueued = 500; // ~3h of 20s fixes per deal
  static const _restartEvery = Duration(seconds: 30);

  final _repo = TrackingRepository();
  final _cache = CacheService();

  /// Deals being tracked, with when each last got a fix.
  final _active = <int, DateTime?>{};
  final activeDealIds = <int>{}.obs;
  final permission = TrackerPermission.unknown.obs;

  Duration _interval = _defaultInterval;
  StreamSubscription<Position>? _positions;
  StreamSubscription<bool>? _online;
  bool _flushing = false;
  bool _starting = false;
  Timer? _restartTimer;
  AppLifecycleListener? _lifecycle;

  @override
  void onInit() {
    super.onInit();
    // back from Settings or the background: pick sharing up again if the
    // stream died, and re-check with the server which deals are ONGOING
    _lifecycle = AppLifecycleListener(onResume: () {
      if (_active.isNotEmpty && _positions == null) unawaited(_startStream(ask: false));
      unawaited(resumeFromServer());
    });
  }

  /// Restarts sharing straight after launch (or a return to the app) without
  /// waiting for the Deals tab: asks the API for this user's ONGOING deals
  /// and reconciles. Offline, whatever is already running keeps running.
  Future<void> resumeFromServer() async {
    if (!Get.isRegistered<SessionService>() || !Get.find<SessionService>().loggedIn) {
      return;
    }
    try {
      final ongoing = await DealsRepository().list(DealStatus.outgoing.apiValue);
      await syncFromDeals(ongoing);
    } catch (e) {
      if (kDebugMode) print('tracker: resume failed $e');
    }
  }

  bool isTracking(int dealId) => _active.containsKey(dealId);

  /// True when this user should be sharing location for [deal].
  static bool shouldTrack(Deal deal) =>
      deal.isTraveler && deal.isLocal && deal.status == DealStatus.outgoing;

  /// Reconciles with a fresh deal list: starts what should run, stops what
  /// ended. Called after every deals load, so a deal completed elsewhere (web,
  /// auto-completion, admin) stops tracking on the next refresh.
  Future<void> syncFromDeals(Iterable<Deal> deals) async {
    final wanted = deals.where(shouldTrack).toList();
    final wantedIds = wanted.map((d) => d.id).toSet();
    for (final id in _active.keys.toList()) {
      if (!wantedIds.contains(id)) await stop(id);
    }
    for (final d in wanted) {
      await ensure(d);
    }
  }

  /// Starts sharing for [deal] if it qualifies, or stops it if it no longer
  /// does. Safe to call on every deal reload.
  Future<void> ensure(Deal deal) async {
    if (!shouldTrack(deal)) {
      if (isTracking(deal.id)) await stop(deal.id);
      return;
    }
    final secs = deal.extras.trackingIntervalSeconds;
    if (secs != null && secs >= 5) _interval = Duration(seconds: secs);
    if (isTracking(deal.id)) {
      // already wanted, but the GPS stream died (permission, services off)
      if (_positions == null) await _startStream(ask: false);
      return;
    }
    _active[deal.id] = null;
    activeDealIds.add(deal.id);
    await _startStream();
    unawaited(_flush(deal.id));
  }

  /// Stops sharing for one deal; the GPS stream goes when none are left.
  Future<void> stop(int dealId) async {
    _active.remove(dealId);
    activeDealIds.remove(dealId);
    // fixes from a finished deal are no longer wanted by the server
    await _cache.delete('$_queuePrefix$dealId');
    if (_active.isEmpty) await _stopStream();
  }

  /// Logout: nothing keeps running for the next account.
  Future<void> stopAll() async {
    for (final id in _active.keys.toList()) {
      await stop(id);
    }
    await _stopStream();
  }

  /// Asks again after the user fixed it in Settings.
  Future<void> retry() async {
    await _stopStream();
    if (_active.isNotEmpty) await _startStream();
  }

  Future<void> openSettings() async {
    if (permission.value == TrackerPermission.servicesOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  // ---------------------------------------------------------------- stream

  /// [ask] = false only checks: a silent background retry must never pop
  /// the system permission dialog again and again.
  Future<bool> _ensurePermission({bool ask = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      permission.value = TrackerPermission.servicesOff;
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied && ask) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      permission.value = TrackerPermission.denied;
      return false;
    }
    if (p == LocationPermission.whileInUse && !ask) {
      // keep whatever the last ask decided (foregroundOnly / granted)
      if (permission.value != TrackerPermission.granted) {
        permission.value = TrackerPermission.foregroundOnly;
      }
    } else if (p == LocationPermission.whileInUse) {
      // background ("Always") is a separate ask on both platforms; without it
      // sharing still runs while the app is open
      try {
        final always = await ph.Permission.locationAlways.request();
        permission.value =
            always.isGranted ? TrackerPermission.granted : TrackerPermission.foregroundOnly;
      } catch (_) {
        permission.value = TrackerPermission.foregroundOnly;
      }
    } else {
      permission.value = TrackerPermission.granted;
    }
    return true;
  }

  LocationSettings _settings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: _interval,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'tracking_notification_title'.tr,
          notificationText: 'tracking_notification_text'.tr,
          notificationChannelName: 'tracking_channel_name'.tr,
          notificationIcon:
              const AndroidResource(name: 'ic_stat_notification', defType: 'drawable'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high);
  }

  Future<void> _startStream({bool ask = true}) async {
    if (_positions != null || _starting) return;
    _starting = true;
    try {
      if (!await _ensurePermission(ask: ask)) {
        _scheduleRestart();
        return;
      }
      // the deal may have ended while the permission check was running
      if (_active.isEmpty) return;
      _positions = Geolocator.getPositionStream(locationSettings: _settings()).listen(
        _onPosition,
        onError: (Object e) {
          if (kDebugMode) print('tracker: stream error $e');
          // permission revoked or services switched off mid-delivery: drop
          // the dead stream and keep trying quietly until it's back
          _positions?.cancel();
          _positions = null;
          unawaited(_ensurePermission(ask: false));
          _scheduleRestart();
        },
      );
      _restartTimer?.cancel();
      _restartTimer = null;
    } catch (e) {
      if (kDebugMode) print('tracker: could not start $e');
      _scheduleRestart();
    } finally {
      _starting = false;
    }
    _online ??= ConnectivityService().connectivityStream.listen((up) {
      if (up) _flushAll();
    });
  }

  /// While a deal still wants sharing but the stream is down, retry every
  /// [_restartEvery] without prompting. Stops once running or nothing's left.
  void _scheduleRestart() {
    if (_restartTimer != null) return;
    _restartTimer = Timer.periodic(_restartEvery, (t) {
      if (_active.isEmpty || _positions != null) {
        t.cancel();
        _restartTimer = null;
        return;
      }
      unawaited(_startStream(ask: false));
    });
  }

  Future<void> _stopStream() async {
    _restartTimer?.cancel();
    _restartTimer = null;
    await _positions?.cancel();
    _positions = null;
    await _online?.cancel();
    _online = null;
  }

  void _onPosition(Position pos) {
    final now = DateTime.now();
    final point = TrackPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      speed: pos.speed >= 0 ? pos.speed : null,
      heading: pos.heading >= 0 ? pos.heading : null,
      recordedAt: pos.timestamp,
    );
    for (final id in _active.keys.toList()) {
      final last = _active[id];
      // the stream can fire more often than asked for — keep to the interval
      if (last != null && now.difference(last) < _interval - const Duration(seconds: 2)) {
        continue;
      }
      _active[id] = now;
      unawaited(_send(id, point));
    }
  }

  Future<void> _send(int dealId, TrackPoint point) async {
    try {
      await _flush(dealId);
      await _repo.send(dealId, point);
    } on NoInternetException {
      await _enqueue(dealId, point);
    } on TimeoutException {
      await _enqueue(dealId, point);
    } on ServerException catch (e) {
      // 409: not ONGOING any more · 403: no longer this user's delivery
      if (e.statusCode == 409 || e.statusCode == 403 || e.statusCode == 404) {
        await stop(dealId);
      } else if ((e.statusCode ?? 500) >= 500) {
        await _enqueue(dealId, point);
      }
    } catch (_) {
      await _enqueue(dealId, point);
    }
  }

  // ------------------------------------------------------- offline buffer

  List<TrackPoint> _queued(int dealId) {
    final raw = _cache.get<String>('$_queuePrefix$dealId');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map(TrackPoint.tryParse)
          .whereType<TrackPoint>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _enqueue(int dealId, TrackPoint p) async {
    if (!isTracking(dealId)) return;
    final q = _queued(dealId)..add(p);
    final trimmed = q.length > _maxQueued ? q.sublist(q.length - _maxQueued) : q;
    await _cache.put('$_queuePrefix$dealId',
        jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  Future<void> _flushAll() async {
    for (final id in _active.keys.toList()) {
      await _flush(id);
    }
  }

  Future<void> _flush(int dealId) async {
    if (_flushing) return;
    final q = _queued(dealId);
    if (q.isEmpty) return;
    _flushing = true;
    try {
      // oldest first, so the server's trail is in recorded order
      q.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      await _repo.sendBatch(dealId, q);
      await _cache.delete('$_queuePrefix$dealId');
    } on ServerException catch (e) {
      if (e.statusCode == 409 || e.statusCode == 403 || e.statusCode == 404) {
        await stop(dealId);
      }
    } catch (_) {
      // still offline — keep the buffer for the next try
    } finally {
      _flushing = false;
    }
  }

  @override
  void onClose() {
    _lifecycle?.dispose();
    _stopStream();
    super.onClose();
  }
}
