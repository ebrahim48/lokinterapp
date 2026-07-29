import 'dart:async';

import 'package:get/get.dart';
import '../../../core/services/data_bus.dart';
import '../data/notifications_repository.dart';

// Keeps the unread count for the bell icon. The notifications screen owns its
// own list; this only exists so the badge is visible before opening it.
class NotificationsBadgeController extends GetxController {
  final unread = 0.obs;

  final _repo = NotificationsRepository();
  StreamSubscription<DataTopic>? _sub;
  Timer? _poll;

  @override
  void onInit() {
    super.onInit();
    refreshCount();
    // deal/post activity is what generates notifications
    _sub = DataBus.on({DataTopic.deals, DataTopic.posts})
        .listen((_) => refreshCount());
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => refreshCount());
  }

  Future<void> refreshCount() async {
    try {
      final items = await _repo.list();
      unread.value = items.where((n) => !n.read).length;
    } catch (_) {
      // a failed poll just leaves the last known count in place
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    _poll?.cancel();
    super.onClose();
  }
}
