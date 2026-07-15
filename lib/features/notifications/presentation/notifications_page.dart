import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/storage_service.dart';
import '../data/notification_model.dart';
import '../data/notifications_repository.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _repo = NotificationsRepository();
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;
  StreamSubscription? _sub;

  bool get _guest => Get.find<SessionService>().isGuest;

  @override
  void initState() {
    super.initState();
    if (!_guest) {
      _load();
      // a new push while the list is open drops it in without a manual refresh
      _sub = Get.find<SocketService>().notificationEvents.listen((_) => _load());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _markAll() async {
    try {
      await _repo.markAllRead();
      _load();
    } on AppException catch (_) {}
  }

  void _open(AppNotification n) {
    if (!n.read && n.id.isNotEmpty) {
      _repo.markRead(n.id).then((_) => _load()).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_items.any((n) => !n.read))
            IconButton(
              tooltip: 'Mark all read',
              onPressed: _markAll,
              icon: const Icon(Icons.done_all),
            ),
          IconButton(
            tooltip: 'Notification settings',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: _guest
          ? Center(
              child: Text('Log in to see your notifications',
                  style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!,
                              style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                          TextButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _items.isEmpty
                      ? Center(
                          child: Text('Nothing here yet',
                              style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, indent: 70.w, color: cs.outline),
                            itemBuilder: (_, i) {
                              final n = _items[i];
                              return Container(
                                color: n.read ? null : n.type.color.withValues(alpha: 0.06),
                                child: ListTile(
                                  onTap: () => _open(n),
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                                  leading: CircleAvatar(
                                    radius: 22.r,
                                    backgroundColor: n.type.color.withValues(alpha: 0.14),
                                    child: Icon(n.type.icon, color: n.type.color, size: 20.sp),
                                  ),
                                  title: Text(n.title,
                                      style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onSurface)),
                                  subtitle: Padding(
                                    padding: EdgeInsets.only(top: 2.h),
                                    child: Text(n.body,
                                        style: TextStyle(
                                            fontSize: 12.sp,
                                            color: cs.onSurfaceVariant,
                                            height: 1.3)),
                                  ),
                                  trailing: Text(n.time,
                                      style:
                                          TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
                                ),
                              );
                            },
                          ),
                        ),
    );
  }

  void _openSettings(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (_) => const _NotificationSettings(),
    );
  }
}

// No backend for these yet — the toggles persist locally until the
// notification-settings endpoints land.
class _NotificationSettings extends StatefulWidget {
  const _NotificationSettings();

  @override
  State<_NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<_NotificationSettings> {
  final _storage = Get.find<StorageService>();

  late bool _push = _storage.getBool('notif_push') ?? true;
  late bool _trips = _storage.getBool('notif_trips') ?? true;
  late bool _requests = _storage.getBool('notif_requests') ?? true;
  late bool _marketing = _storage.getBool('notif_marketing') ?? false;

  void _set(String key, bool value) => _storage.setBool(key, value);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 18.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notification settings', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 8.h),
            _toggle('Push notifications', _push, (v) {
              setState(() => _push = v);
              _set('notif_push', v);
            }),
            _toggle('Trip alerts', _trips, (v) {
              setState(() => _trips = v);
              _set('notif_trips', v);
            }),
            _toggle('Delivery request alerts', _requests, (v) {
              setState(() => _requests = v);
              _set('notif_requests', v);
            }),
            _toggle('Marketing & promotions', _marketing, (v) {
              setState(() => _marketing = v);
              _set('notif_marketing', v);
            }),
          ],
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(fontSize: 14.sp)),
      value: value,
      onChanged: onChanged,
    );
  }
}
