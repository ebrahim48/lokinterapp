import 'package:get/get.dart';
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import 'notification_model.dart';

class NotificationsRepository {
  final _api = Get.find<ApiService>();

  /// Server-side notification preferences (push on/off, trip and request
  /// alerts, marketing, and the countries the user cares about).
  Future<Map<String, dynamic>> preferences() async {
    final res = await _api.get('/notifications/preferences');
    final data = unwrapData(res);
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<void> updatePreferences({
    bool? push,
    bool? trips,
    bool? requests,
    bool? marketing,
    List<String>? countries,
  }) async {
    unwrapData(await _api.post('/notifications/preferences', data: {
      if (push != null) 'notifyPushEnabled': push,
      if (trips != null) 'notifyTrips': trips,
      if (requests != null) 'notifyRequests': requests,
      if (marketing != null) 'notifyMarketing': marketing,
      if (countries != null) 'notifyCountries': countries,
    }));
  }

  Future<List<AppNotification>> list() async {
    final res = await _api.get('/notifications/getNotifications',
        queryParameters: {'limit': 100});
    return Paged.fromJson(unwrapData(res), AppNotification.fromJson).list;
  }

  Future<void> markRead(String id) async {
    unwrapData(await _api.post('/notifications/markAsRead/$id'));
  }

  Future<void> markAllRead() async {
    unwrapData(await _api.post('/notifications/markAllAsRead'));
  }
}
