import 'package:get/get.dart';

import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/realtime_config.dart';
import '../../../core/services/socket_service.dart';
import 'tracking_models.dart';

/// Track My Order endpoints (REQ §6 · GUIDE Screens 6, 7).
class TrackingRepository {
  final _api = Get.find<ApiService>();

  /// Sender / transporter / admin read of the live position.
  Future<TrackingSnapshot> snapshot(int dealId) async {
    final data = unwrapData(await _api.get('/deals/$dealId/tracking'));
    final snap = TrackingSnapshot.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
    _useRealtime(snap.realtime);
    return snap;
  }

  /// Transporter app, when a deal screen opens: should this device send GPS
  /// for the deal, and how often.
  Future<TrackingSettings> settings(int dealId) async {
    final data = unwrapData(await _api.get('/deals/$dealId/tracking/settings'));
    final settings = TrackingSettings.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
    _useRealtime(settings.realtime);
    return settings;
  }

  /// The tracking responses carry the server's `realtime` block too — hand
  /// it to the socket so a changed key/cluster takes effect.
  void _useRealtime(RealtimeConfig? cfg) {
    if (cfg == null || !Get.isRegistered<SocketService>()) return;
    final socket = Get.find<SocketService>();
    if (!cfg.sameConnection(socket.config) || cfg.authEndpoint != socket.config.authEndpoint) {
      socket.applyConfig(cfg);
    }
  }

  /// Transporter sends one fix while the deal is ONGOING.
  Future<void> send(int dealId, TrackPoint point) async {
    unwrapData(
      await _api.post('/deals/$dealId/tracking/location', data: point.toJson()),
    );
  }

  /// Fixes buffered in a dead zone, flushed in one request on reconnect.
  Future<void> sendBatch(int dealId, List<TrackPoint> points) async {
    if (points.isEmpty) return;
    unwrapData(
      await _api.post(
        '/deals/$dealId/tracking/location',
        data: {'points': points.map((p) => p.toJson()).toList()},
      ),
    );
  }
}
