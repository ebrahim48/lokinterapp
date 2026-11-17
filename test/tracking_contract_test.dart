import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_task/features/deals/data/tracking_models.dart';

/// Backend contract of 16 Nov 2026: `tracking/settings`, `tracking` with
/// breadcrumbs + pingIntervalSeconds.
void main() {
  group('TrackingSettings', () {
    test('reads shouldCollect and pingIntervalSeconds', () {
      final s = TrackingSettings.fromJson({'shouldCollect': true, 'pingIntervalSeconds': 15});
      expect(s.shouldCollect, isTrue);
      expect(s.pingIntervalSeconds, 15);
    });

    test('missing / false shouldCollect means do not send', () {
      expect(TrackingSettings.fromJson({}).shouldCollect, isFalse);
      expect(TrackingSettings.fromJson({'shouldCollect': false}).shouldCollect, isFalse);
    });

    test('interval may arrive as a string', () {
      expect(TrackingSettings.fromJson({'pingIntervalSeconds': '30'}).pingIntervalSeconds, 30);
    });
  });

  group('TrackingSnapshot', () {
    final now = DateTime.now().toUtc();
    String ago(int s) => now.subtract(Duration(seconds: s)).toIso8601String();

    test('parses latest location, points, breadcrumbs and interval', () {
      final snap = TrackingSnapshot.fromJson({
        'dealStatus': 'OUTGOING',
        'connectionStatus': 'live',
        'latestLocation': {'latitude': 36.8, 'longitude': 10.18, 'recordedAt': ago(10)},
        'pickup': {'label': 'Tunis', 'lat': 36.8, 'lng': 10.18},
        'dropoff': {'label': 'Sousse', 'lat': 35.83, 'lng': 10.64},
        'breadcrumbs': [
          {'latitude': 36.7, 'longitude': 10.2, 'recordedAt': ago(60)},
          {'latitude': 36.6, 'longitude': 10.3, 'recordedAt': ago(120)},
          {'latitude': 'bad', 'longitude': 10.3},
        ],
        'pingIntervalSeconds': 20,
      });
      expect(snap.link, TrackingLink.live);
      expect(snap.last?.latitude, 36.8);
      expect(snap.pickup?.label, 'Tunis');
      expect(snap.dropoff?.lat, 35.83);
      expect(snap.pingIntervalSeconds, 20);
      // bad point skipped, oldest first
      expect(snap.breadcrumbs.map((p) => p.latitude), [36.6, 36.7]);
      expect(snap.ended, isFalse);
    });

    test('falls back to the newest breadcrumb when no latest location', () {
      final snap = TrackingSnapshot.fromJson({
        'breadcrumbs': [
          {'latitude': 36.6, 'longitude': 10.3, 'recordedAt': ago(300)},
          {'latitude': 36.7, 'longitude': 10.2, 'recordedAt': ago(200)},
        ],
      });
      expect(snap.last?.latitude, 36.7);
      expect(snap.link, TrackingLink.delayed);
    });

    test('no position and no trail → unavailable, nothing invented', () {
      final snap = TrackingSnapshot.fromJson({'dealStatus': 'OUTGOING'});
      expect(snap.last, isNull);
      expect(snap.breadcrumbs, isEmpty);
      expect(snap.link, TrackingLink.unavailable);
    });

    test('older shapes still parse (lastLocation, transporter)', () {
      expect(
        TrackingSnapshot.fromJson({
          'lastLocation': {'latitude': 1, 'longitude': 2, 'recordedAt': ago(5)},
        }).last?.longitude,
        2,
      );
      expect(
        TrackingSnapshot.fromJson({
          'lastPingAt': ago(5),
          'transporter': {'lat': 3, 'lng': 4},
        }).last?.latitude,
        3,
      );
    });

    test('completed / cancelled deals are ended', () {
      expect(TrackingSnapshot.fromJson({'dealStatus': 'COMPLETED'}).ended, isTrue);
      expect(TrackingSnapshot.fromJson({'dealStatus': 'CANCELLED'}).ended, isTrue);
    });
  });

  group('Backend answers 16 Nov', () {
    final now = DateTime.now().toUtc();
    String ago(int s) => now.subtract(Duration(seconds: s)).toIso8601String();

    test('settings: trackingState ended stops even with shouldCollect', () {
      final s = TrackingSettings.fromJson({
        'shouldCollect': true,
        'trackingState': 'ended',
        'maxBatchPoints': 200,
      });
      expect(s.ended, isTrue);
      expect(s.collect, isFalse);
      expect(s.maxBatchPoints, 200);
      expect(TrackingSettings.fromJson({'shouldCollect': true}).collect, isTrue);
    });

    test('currentLocation wins; breadcrumbs use lat/lng', () {
      final snap = TrackingSnapshot.fromJson({
        'dealStatus': 'OUTGOING',
        'connectionStatus': 'delayed',
        'lastPingMinutesAgo': 4,
        'currentLocation': {
          'latitude': 36.8, 'longitude': 10.18, 'accuracy': 12.5,
          'heading': 90, 'speed': 8.2, 'recordedAt': ago(240),
        },
        'transporter': {'lat': 1, 'lng': 1},
        'breadcrumbs': [
          {'lat': 36.6, 'lng': 10.1, 'recordedAt': ago(400)},
          {'lat': 36.7, 'lng': 10.15, 'recordedAt': ago(300)},
        ],
        'hasTraveledPath': true,
      });
      expect(snap.last?.latitude, 36.8);
      expect(snap.last?.accuracy, 12.5);
      expect(snap.link, TrackingLink.delayed);
      expect(snap.lastPingMinutesAgo, 4);
      expect(snap.breadcrumbs.map((p) => p.latitude), [36.6, 36.7]);
    });

    test('currentLocation null → no invented position', () {
      final snap = TrackingSnapshot.fromJson({
        'dealStatus': 'OUTGOING',
        'currentLocation': null,
        'connectionStatus': 'unavailable',
      });
      expect(snap.last, isNull);
    });

    test('route (latitude/longitude) is read when breadcrumbs absent', () {
      final snap = TrackingSnapshot.fromJson({
        'route': [
          {'latitude': 36.6, 'longitude': 10.1, 'recordedAt': ago(100)},
        ],
      });
      expect(snap.breadcrumbs.single.longitude, 10.1);
    });

    test('completed vs cancelled', () {
      expect(TrackingSnapshot.fromJson({'dealStatus': 'COMPLETED'}).completed, isTrue);
      final c = TrackingSnapshot.fromJson({'dealStatus': 'CANCELLED'});
      expect(c.ended, isTrue);
      expect(c.completed, isFalse);
      expect(TrackingSnapshot.fromJson({'trackingState': 'ended'}).ended, isTrue);
    });
  });

  group('TrackingLink.fromAge', () {
    test('live < 2 min, delayed to 10 min, then unavailable', () {
      final n = DateTime.now();
      expect(TrackingLinkX.fromAge(n.subtract(const Duration(seconds: 30))), TrackingLink.live);
      expect(TrackingLinkX.fromAge(n.subtract(const Duration(minutes: 5))), TrackingLink.delayed);
      expect(TrackingLinkX.fromAge(n.subtract(const Duration(minutes: 11))), TrackingLink.unavailable);
      expect(TrackingLinkX.fromAge(null), TrackingLink.unavailable);
    });
  });
}
