import 'package:get/get.dart';
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import 'notification_model.dart';

class NotificationsRepository {
  final _api = Get.find<ApiService>();

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
