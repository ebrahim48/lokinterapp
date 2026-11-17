/// Live-update settings each server hands the app (`GET /realtime-config`,
/// also as `realtime` inside `GET /deals/{id}/tracking` and
/// `/tracking/settings`). Only the public Pusher key ever comes down.
///
/// The values built into the app are the last resort, used when the server
/// can't be reached and nothing was saved from an earlier login.
class RealtimeConfig {
  static const fallbackKey = '6be7243295ab894483a1';
  static const fallbackCluster = 'ap1';
  static const defaultLocationEvent = 'deal.location.updated';
  static const defaultStoppedEvent = 'deal.tracking.stopped';

  /// False when the server doesn't broadcast over Pusher: the app polls.
  final bool enabled;
  final String driver;
  final String key;
  final String cluster;
  /// Self-hosted socket server (Reverb / Soketi). The Pusher Flutter plugin
  /// can only reach Pusher's own cluster hosts, so a custom host means poll.
  final String? host;
  final int? port;
  final bool useTLS;
  /// Full URL of `/broadcasting/auth`; null → the app builds it from its base.
  final String? authEndpoint;
  final String channelPrefix;
  final String locationEvent;
  final String stoppedEvent;

  const RealtimeConfig({
    this.enabled = true,
    this.driver = 'pusher',
    this.key = fallbackKey,
    this.cluster = fallbackCluster,
    this.host,
    this.port,
    this.useTLS = true,
    this.authEndpoint,
    this.channelPrefix = 'private-deal.',
    this.locationEvent = defaultLocationEvent,
    this.stoppedEvent = defaultStoppedEvent,
  });

  static const fallback = RealtimeConfig();

  /// Whether the socket can be used with this config at all.
  bool get usable =>
      enabled &&
      driver.toLowerCase() == 'pusher' &&
      key.isNotEmpty &&
      cluster.isNotEmpty &&
      (host == null || host!.isEmpty);

  static RealtimeConfig? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final key = _str(raw['key']);
    final enabled = raw['enabled'] is bool ? raw['enabled'] as bool : key != null;
    final events = raw['events'] is Map ? raw['events'] as Map : const {};
    return RealtimeConfig(
      enabled: enabled,
      driver: _str(raw['driver']) ?? 'pusher',
      key: key ?? '',
      cluster: _str(raw['cluster']) ?? '',
      host: _str(raw['host']),
      port: raw['port'] is num ? (raw['port'] as num).toInt() : int.tryParse('${raw['port'] ?? ''}'),
      useTLS: raw['useTLS'] is bool ? raw['useTLS'] as bool : true,
      authEndpoint: _str(raw['authEndpoint']),
      channelPrefix: _str(raw['channelPrefix']) ?? 'private-deal.',
      locationEvent: _str(events['locationUpdated']) ?? defaultLocationEvent,
      stoppedEvent: _str(events['trackingStopped']) ?? defaultStoppedEvent,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'driver': driver,
        'key': key,
        'cluster': cluster,
        'host': host,
        'port': port,
        'useTLS': useTLS,
        'authEndpoint': authEndpoint,
        'channelPrefix': channelPrefix,
        'events': {'locationUpdated': locationEvent, 'trackingStopped': stoppedEvent},
      };

  /// Same connection (a changed key/cluster means the socket must restart).
  bool sameConnection(RealtimeConfig o) =>
      key == o.key && cluster == o.cluster && useTLS == o.useTLS && usable == o.usable;

  static String? _str(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return (s.isEmpty || s == 'null') ? null : s;
  }
}
