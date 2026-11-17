import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/realtime_config.dart';
import '../../../core/utils/format.dart';

/// LIVE (< 2 min) · DELAYED (2–10 min) · UNAVAILABLE (> 10 min or none) —
/// GUIDE Screen 6.2.
enum TrackingLink { live, delayed, unavailable }

extension TrackingLinkX on TrackingLink {
  static TrackingLink parse(dynamic raw) =>
      switch ('${raw ?? ''}'.toUpperCase()) {
        'LIVE' => TrackingLink.live,
        'DELAYED' => TrackingLink.delayed,
        _ => TrackingLink.unavailable,
      };

  /// From the age of the last fix — so the pill degrades on its own when the
  /// transporter goes quiet, without waiting for the server to say so.
  static TrackingLink fromAge(DateTime? recordedAt) {
    if (recordedAt == null) return TrackingLink.unavailable;
    final age = DateTime.now().difference(recordedAt);
    if (age < const Duration(minutes: 2)) return TrackingLink.live;
    if (age <= const Duration(minutes: 10)) return TrackingLink.delayed;
    return TrackingLink.unavailable;
  }

  String get label => switch (this) {
    TrackingLink.live => 'tracking_live'.tr,
    TrackingLink.delayed => 'tracking_delayed'.tr,
    TrackingLink.unavailable => 'tracking_unavailable'.tr,
  };

  Color get color => switch (this) {
    TrackingLink.live => const Color(0xFF16A34A),
    TrackingLink.delayed => const Color(0xFFD97706),
    TrackingLink.unavailable => const Color(0xFF6B7280),
  };
}

/// One GPS fix. [recordedAt] is when the device took it, not when it arrived.
class TrackPoint {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final DateTime recordedAt;

  const TrackPoint({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (accuracy != null) 'accuracy': accuracy,
    if (speed != null) 'speed': speed,
    if (heading != null) 'heading': heading,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
  };

  static TrackPoint? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final lat = _d(raw['latitude'] ?? raw['lat']);
    final lng = _d(raw['longitude'] ?? raw['lng']);
    if (lat == null || lng == null) return null;
    final at =
        '${raw['recordedAt'] ?? raw['recorded_at'] ?? raw['lastPingAt'] ?? raw['receivedAt'] ?? ''}';
    return TrackPoint(
      latitude: lat,
      longitude: lng,
      accuracy: _d(raw['accuracy']),
      speed: _d(raw['speed']),
      heading: _d(raw['heading']),
      recordedAt: (at.isEmpty ? null : parseServerDate(at)) ?? DateTime.now(),
    );
  }

  static double? _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
}

/// A pinned place on the tracking map (pickup / drop-off).
class TrackPlace {
  final String label;
  final double lat;
  final double lng;
  const TrackPlace(this.label, this.lat, this.lng);

  static TrackPlace? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final lat = TrackPoint._d(raw['lat'] ?? raw['latitude']);
    final lng = TrackPoint._d(raw['lng'] ?? raw['longitude']);
    if (lat == null || lng == null) return null;
    final label = '${raw['label'] ?? raw['address'] ?? ''}';
    return TrackPlace(label == '-' ? '' : label, lat, lng);
  }
}

/// `GET /deals/{id}/tracking/settings` — asked by the transporter app when a
/// deal screen opens and when the app starts. [shouldCollect] is true only
/// for the deal's transporter while the deal is ongoing.
class TrackingSettings {
  final bool shouldCollect;

  /// How often to send a fix.
  final int? pingIntervalSeconds;

  /// e.g. "active" / "ended". "ended" = stop GPS and clear saved points.
  final String? trackingState;

  /// Most points one offline batch may carry (server default 500).
  final int? maxBatchPoints;

  /// Days GPS points of ended deals are kept; 0 = no period approved yet.
  final int? retentionDays;

  /// This server's live-update settings, when it sends them.
  final RealtimeConfig? realtime;

  const TrackingSettings({
    this.shouldCollect = false,
    this.pingIntervalSeconds,
    this.trackingState,
    this.maxBatchPoints,
    this.retentionDays,
    this.realtime,
  });

  bool get ended => (trackingState ?? '').toLowerCase() == 'ended';

  /// Send GPS only when the server says so and tracking hasn't ended.
  bool get collect => shouldCollect && !ended;

  factory TrackingSettings.fromJson(Map<String, dynamic> json) => TrackingSettings(
        shouldCollect: json['shouldCollect'] == true || json['should_collect'] == true,
        pingIntervalSeconds: _int(json['pingIntervalSeconds'] ??
            json['ping_interval_seconds'] ??
            json['trackingIntervalSeconds'] ??
            json['intervalSeconds']),
        trackingState: _str(json['trackingState'] ?? json['tracking_state']),
        maxBatchPoints: _int(json['maxBatchPoints'] ?? json['max_batch_points']),
        retentionDays: _int(json['retentionDays'] ?? json['retention_days']),
        realtime: RealtimeConfig.tryParse(json['realtime']),
      );
}

int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

String? _str(dynamic v) {
  final s = '${v ?? ''}'.trim();
  return (s.isEmpty || s == 'null') ? null : s;
}

/// `GET /deals/{id}/tracking` (same data on `/tracking-status`)
class TrackingSnapshot {
  final String dealStatus;
  final bool active;
  final TrackingLink link;
  final TrackPoint? last;
  final TrackPlace? pickup;
  final TrackPlace? dropoff;

  /// The transporter's recent recorded fixes (latest 100), oldest first.
  /// Real GPS points only — drawn as the path already travelled, never as a
  /// planned route.
  final List<TrackPoint> breadcrumbs;

  /// How often the transporter app sends a fix — the map polls at this pace.
  final int? pingIntervalSeconds;

  /// Server's minutes since the last fix — "last seen X min ago".
  final int? lastPingMinutesAgo;

  /// e.g. "active" / "ended".
  final String? trackingState;

  /// This server's live-update settings, when it sends them.
  final RealtimeConfig? realtime;

  const TrackingSnapshot({
    this.dealStatus = '',
    this.active = false,
    this.link = TrackingLink.unavailable,
    this.last,
    this.pickup,
    this.dropoff,
    this.breadcrumbs = const [],
    this.pingIntervalSeconds,
    this.lastPingMinutesAgo,
    this.trackingState,
    this.realtime,
  });

  bool get completed => dealStatus.toUpperCase() == 'COMPLETED';

  bool get ended {
    final s = dealStatus.toUpperCase();
    return s == 'COMPLETED' ||
        s.startsWith('CANCEL') ||
        s == 'REJECTED' ||
        (trackingState ?? '').toLowerCase() == 'ended';
  }

  factory TrackingSnapshot.fromJson(Map<String, dynamic> json) {
    // `currentLocation` is the latest fix (null until the first one);
    // `transporter` carries the same with lat/lng keys (+ lastPingAt at the
    // top level). Older shapes used latestLocation / lastLocation / location.
    final transporter = json['transporter'] is Map
        ? {
            'lastPingAt': json['lastPingAt'],
            ...Map<String, dynamic>.from(json['transporter']),
          }
        : null;
    // breadcrumbs: [{lat, lng, recordedAt}], oldest → newest; `route` is the
    // same list with latitude/longitude keys
    final crumbsRaw = json['breadcrumbs'] ?? json['route'] ?? json['trail'] ?? json['history'];
    final crumbs = crumbsRaw is List
        ? (crumbsRaw.map(TrackPoint.tryParse).whereType<TrackPoint>().toList()
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt)))
        : <TrackPoint>[];
    final last = TrackPoint.tryParse(json['currentLocation']) ??
        TrackPoint.tryParse(transporter) ??
        TrackPoint.tryParse(json['latestLocation']) ??
        TrackPoint.tryParse(json['lastLocation']) ??
        TrackPoint.tryParse(json['location']) ??
        TrackPoint.tryParse(json) ??
        (crumbs.isEmpty ? null : crumbs.last);
    return TrackingSnapshot(
      dealStatus: '${json['dealStatus'] ?? json['status'] ?? ''}',
      active: json['isTrackingActive'] == true ||
          json['trackingActive'] == true ||
          json['active'] == true,
      link: json['connectionStatus'] != null
          ? TrackingLinkX.parse(json['connectionStatus'])
          : TrackingLinkX.fromAge(last?.recordedAt),
      last: last,
      pickup: TrackPlace.tryParse(json['pickup']),
      dropoff: TrackPlace.tryParse(json['dropoff']),
      breadcrumbs: crumbs,
      pingIntervalSeconds: _int(json['pingIntervalSeconds'] ??
          json['ping_interval_seconds'] ??
          json['trackingIntervalSeconds']),
      lastPingMinutesAgo: _int(json['lastPingMinutesAgo'] ?? json['last_ping_minutes_ago']),
      trackingState: _str(json['trackingState'] ?? json['tracking_state']),
      realtime: RealtimeConfig.tryParse(json['realtime']),
    );
  }
}
