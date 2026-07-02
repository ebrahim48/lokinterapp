import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../data/notification_model.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Notification settings',
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView.separated(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: mockNotifications.length,
        separatorBuilder: (_, __) => Divider(height: 1, indent: 70.w, color: cs.outline),
        itemBuilder: (_, i) {
          final n = mockNotifications[i];
          return Container(
            color: n.read ? null : n.type.color.withValues(alpha: 0.06),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              leading: CircleAvatar(
                radius: 22.r,
                backgroundColor: n.type.color.withValues(alpha: 0.14),
                child: Icon(n.type.icon, color: n.type.color, size: 20.sp),
              ),
              title: Text(n.title,
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Text(n.body,
                    style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, height: 1.3)),
              ),
              trailing: Text(n.time, style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
            ),
          );
        },
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

class _NotificationSettings extends StatefulWidget {
  const _NotificationSettings();

  @override
  State<_NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<_NotificationSettings> {
  bool _push = true, _trips = true, _requests = true, _marketing = false;

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
            _toggle('Push notifications', _push, (v) => setState(() => _push = v)),
            _toggle('Trip alerts', _trips, (v) => setState(() => _trips = v)),
            _toggle('Delivery request alerts', _requests, (v) => setState(() => _requests = v)),
            _toggle('Marketing & promotions', _marketing, (v) => setState(() => _marketing = v)),
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
