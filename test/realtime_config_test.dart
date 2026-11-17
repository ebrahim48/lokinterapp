import 'package:flutter_task/core/services/realtime_config.dart';
import 'package:flutter_task/features/deals/data/tracking_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backend 16 Nov: `/realtime-config` + `realtime` / `retentionDays` in the
/// tracking responses.
void main() {
  const sample = {
    'enabled': true,
    'driver': 'pusher',
    'key': 'abc123',
    'cluster': 'eu',
    'host': null,
    'port': null,
    'useTLS': true,
    'authEndpoint': 'https://api.example.com/broadcasting/auth',
    'channelPrefix': 'private-deal.',
    'events': {
      'locationUpdated': 'deal.location.updated',
      'trackingStopped': 'deal.tracking.stopped',
    },
  };

  test('reads the server config', () {
    final c = RealtimeConfig.tryParse(sample)!;
    expect(c.key, 'abc123');
    expect(c.cluster, 'eu');
    expect(c.authEndpoint, 'https://api.example.com/broadcasting/auth');
    expect(c.locationEvent, 'deal.location.updated');
    expect(c.stoppedEvent, 'deal.tracking.stopped');
    expect(c.usable, isTrue);
  });

  test('enabled false → not usable (polling)', () {
    final c = RealtimeConfig.tryParse({...sample, 'enabled': false})!;
    expect(c.usable, isFalse);
  });

  test('self-hosted host or another driver → not usable', () {
    expect(RealtimeConfig.tryParse({...sample, 'host': 'ws.example.com'})!.usable, isFalse);
    expect(RealtimeConfig.tryParse({...sample, 'driver': 'reverb'})!.usable, isFalse);
  });

  test('round-trips through the saved copy', () {
    final c = RealtimeConfig.tryParse(sample)!;
    final back = RealtimeConfig.tryParse(c.toJson())!;
    expect(back.sameConnection(c), isTrue);
    expect(back.authEndpoint, c.authEndpoint);
  });

  test('key or cluster change means a new connection', () {
    final c = RealtimeConfig.tryParse(sample)!;
    expect(RealtimeConfig.tryParse({...sample, 'cluster': 'ap1'})!.sameConnection(c), isFalse);
    expect(RealtimeConfig.tryParse({...sample, 'key': 'zzz'})!.sameConnection(c), isFalse);
  });

  test('built-in fallback is the old hardcoded pair', () {
    expect(RealtimeConfig.fallback.key, '6be7243295ab894483a1');
    expect(RealtimeConfig.fallback.cluster, 'ap1');
    expect(RealtimeConfig.fallback.usable, isTrue);
  });

  test('tracking settings carry realtime and retentionDays', () {
    final s = TrackingSettings.fromJson({
      'shouldCollect': true,
      'retentionDays': 0,
      'realtime': sample,
    });
    expect(s.retentionDays, 0);
    expect(s.realtime?.key, 'abc123');
    expect(TrackingSnapshot.fromJson({'realtime': sample}).realtime?.cluster, 'eu');
    expect(TrackingSettings.fromJson({}).realtime, isNull);
  });
}
