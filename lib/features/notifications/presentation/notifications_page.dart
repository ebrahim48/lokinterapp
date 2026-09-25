import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/storage_service.dart';
import '../../lookups/data/lookup_models.dart';
import '../../lookups/data/lookups_repository.dart';
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
      final raw = await _repo.list();
      if (!mounted) return;
      setState(() {
        // Deduplicate: same deal + same event title on same day collapses to one
        // notification. This guards against the backend firing two notifications
        // for the same deal status change (e.g. "Deal status updated, rejected"
        // and "Deal status has been changed to rejected").
        _items = deduplicateNotifications(raw);
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
        title: Text('notifications'.tr),
        actions: [
          if (_items.any((n) => !n.read))
            IconButton(
              tooltip: 'mark_all_read'.tr,
              onPressed: _markAll,
              icon: const Icon(Icons.done_all),
            ),
          IconButton(
            tooltip: 'notification_settings'.tr,
            onPressed: () => _openSettings(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: _guest
          ? Center(
              child: Text('log_in_to_see_your_notifications'.tr,
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
                          TextButton(onPressed: _load, child: Text('retry'.tr)),
                        ],
                      ),
                    )
                  : _items.isEmpty
                      ? Center(
                          child: Text('nothing_here_yet'.tr,
                              style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: Builder(builder: (context) {
                            // Filter out chat system messages — backend sends one
                            // FCM per deal event; these would duplicate the inbox.
                            final visible = _items
                                .where((n) => !n.isChatSystemMessage)
                                .toList();
                            if (visible.isEmpty) {
                              return Center(
                                child: Text('nothing_here_yet'.tr,
                                    style: TextStyle(
                                        fontSize: 13.sp,
                                        color: cs.onSurfaceVariant)),
                              );
                            }
                            return ListView.separated(
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              itemCount: visible.length,
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, indent: 70.w, color: cs.outline),
                              itemBuilder: (_, i) {
                                final n = visible[i];
                                return Container(
                                  color: n.read
                                      ? null
                                      : n.type.color.withValues(alpha: 0.06),
                                  child: ListTile(
                                    onTap: () => _open(n),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16.w, vertical: 6.h),
                                    leading: CircleAvatar(
                                      radius: 22.r,
                                      backgroundColor:
                                          n.type.color.withValues(alpha: 0.14),
                                      child: Icon(n.type.icon,
                                          color: n.type.color, size: 20.sp),
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
                                        style: TextStyle(
                                            fontSize: 10.sp,
                                            color: cs.onSurfaceVariant)),
                                  ),
                                );
                              },
                            );
                          }),
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
  final _repo = NotificationsRepository();

  // seeded from the local cache so the sheet paints instantly, then reconciled
  // with the server, which is the source of truth for what actually gets sent
  late bool _push = _storage.getBool('notif_push') ?? true;
  late bool _trips = _storage.getBool('notif_trips') ?? true;
  late bool _requests = _storage.getBool('notif_requests') ?? true;
  late bool _marketing = _storage.getBool('notif_marketing') ?? false;
  // country filter for notifications: empty = all countries
  List<String> _notifyCountries = [];
  List<Country> _allCountries = [];

  @override
  void initState() {
    super.initState();
    _pull();
    // load country list for the multiselect
    LookupsRepository().countries().then((list) {
      if (!mounted) return;
      setState(() => _allCountries = list);
    }).catchError((_) {});
  }

  Future<void> _pull() async {
    try {
      final p = await _repo.preferences();
      if (!mounted || p.isEmpty) return;
      setState(() {
        _push = p['notifyPushEnabled'] ?? _push;
        _trips = p['notifyTrips'] ?? _trips;
        _requests = p['notifyRequests'] ?? _requests;
        _marketing = p['notifyMarketing'] ?? _marketing;
        final raw = p['notifyCountries'];
        if (raw is List) {
          _notifyCountries = raw.whereType<String>().toList();
        }
      });
      _cache();
    } catch (_) {
      // offline: the cached values stay usable
    }
  }

  void _cache() {
    _storage.setBool('notif_push', _push);
    _storage.setBool('notif_trips', _trips);
    _storage.setBool('notif_requests', _requests);
    _storage.setBool('notif_marketing', _marketing);
  }

  // cache locally, then push the whole set so a failed call can't half-apply
  void _set(String _, bool __) {
    _cache();
    _repo
        .updatePreferences(
          push: _push,
          trips: _trips,
          requests: _requests,
          marketing: _marketing,
          countries: _notifyCountries.isEmpty ? null : _notifyCountries,
        )
        .catchError((_) {});
  }

  void _setCountries(List<String> selected) {
    setState(() => _notifyCountries = selected);
    _repo
        .updatePreferences(
          push: _push,
          trips: _trips,
          requests: _requests,
          marketing: _marketing,
          countries: selected.isEmpty ? null : selected,
        )
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final countryNames = _allCountries.map((c) => c.name).toList();
    // Cap the sheet at 80% of the screen so it never overflows on any device.
    final maxHeight = MediaQuery.of(context).size.height * 0.80;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed header — never scrolls away
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 0),
              child: Text('notification_settings'.tr,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 18.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    if (countryNames.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Text(
                        'notify_countries_label'.tr,
                        style: TextStyle(fontSize: 13.sp, color: cs.onSurface),
                      ),
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 4.h,
                        children: countryNames.map((name) {
                          final selected = _notifyCountries.contains(name);
                          return FilterChip(
                            label: Text(name, style: TextStyle(fontSize: 11.sp)),
                            selected: selected,
                            onSelected: (v) {
                              final updated = List<String>.from(_notifyCountries);
                              if (v) {
                                updated.add(name);
                              } else {
                                updated.remove(name);
                              }
                              _setCountries(updated);
                            },
                          );
                        }).toList(),
                      ),
                      if (_notifyCountries.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        TextButton(
                          onPressed: () => _setCountries([]),
                          child: Text('notify_all_countries'.tr,
                              style: TextStyle(fontSize: 12.sp)),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
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
