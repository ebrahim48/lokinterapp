import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/format.dart';

/// LIVE (< 2 min) · DELAYED (2–10 min) · UNAVAILABLE (> 10 min or none) —
/// GUIDE Screen 6.2.
enum TrackingLink { live, delayed, unavailable }

extension TrackingLinkX on TrackingLink {
  static TrackingLink parse(dynamic raw) => switch ('${raw ?? ''}'.toUpperCase()) {
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
    final at = '${raw['recordedAt'] ?? raw['recorded_at'] ?? raw['lastPingAt'] ?? raw['receivedAt'] ?? ''}';
    return TrackPoint(
      latitude: lat,
      longitude: lng,
      accuracy: _d(raw['accuracy']),
      speed: _d(raw['speed']),
      heading: _d(raw['heading']),
      recordedAt: (at.isEmpty ? null : parseServerDate(at)) ?? DateTime.now(),
    );
  }

  static double? _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
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

/// `GET /deals/{id}/tracking`
class TrackingSnapshot {
  final String dealStatus;
  final bool active;
  final TrackingLink link;
  final TrackPoint? last;
  final TrackPlace? pickup;
  final TrackPlace? dropoff;

  const TrackingSnapshot({
    this.dealStatus = '',
    this.active = false,
    this.link = TrackingLink.unavailable,
    this.last,
    this.pickup,
    this.dropoff,
  });

  bool get ended {
    final s = dealStatus.toUpperCase();
    return s == 'COMPLETED' || s.startsWith('CANCEL') || s == 'REJECTED';
  }

  factory TrackingSnapshot.fromJson(Map<String, dynamic> json) {
    // some builds put the last fix at the top level instead of lastLocation
    // the API puts the last fix under `transporter` (with lastPingAt at the
    // top level); older shapes used lastLocation / location
    final transporter = json['transporter'] is Map
        ? {'lastPingAt': json['lastPingAt'], ...Map<String, dynamic>.from(json['transporter'])}
        : null;
    final last = TrackPoint.tryParse(transporter) ??
        TrackPoint.tryParse(json['lastLocation']) ??
        TrackPoint.tryParse(json['location']) ??
        TrackPoint.tryParse(json);
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
    );
  }
}
