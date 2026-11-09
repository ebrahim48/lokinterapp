import 'package:get/get.dart';

import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import 'tracking_models.dart';

/// Track My Order endpoints (REQ §6 · GUIDE Screens 6, 7).
class TrackingRepository {
  final _api = Get.find<ApiService>();

  /// Sender / transporter / admin read of the live position.
  Future<TrackingSnapshot> snapshot(int dealId) async {
    final data = unwrapData(await _api.get('/deals/$dealId/tracking'));
    return TrackingSnapshot.fromJson(
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
  }

  /// Transporter sends one fix while the deal is ONGOING.
  Future<void> send(int dealId, TrackPoint point) async {
    unwrapData(await _api.post('/deals/$dealId/tracking/location', data: point.toJson()));
  }

  /// Fixes buffered in a dead zone, flushed in one request on reconnect.
  Future<void> sendBatch(int dealId, List<TrackPoint> points) async {
    if (points.isEmpty) return;
    unwrapData(await _api.post('/deals/$dealId/tracking/location',
        data: {'points': points.map((p) => p.toJson()).toList()}));
  }
}
