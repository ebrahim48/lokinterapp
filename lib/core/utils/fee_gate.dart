import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/fees/presentation/fee_ledgers_page.dart';
import '../exceptions/app_exceptions.dart';
import '../services/session_service.dart';

/// Overdue transporter-fee restrictions (REQ §10.2 · GUIDE Screen 10).
///
/// While a fee ledger is OVERDUE three things are blocked — posting a trip,
/// accepting a deal and starting a NEW chat. Everything else stays open:
/// ongoing deliveries, existing chats, disputes, the ledgers and paying.
/// The state comes from `/auth/user` (`feeRestrictions`), so buttons can be
/// gated before the tap; the API's 403 `LEDGER_OVERDUE` is the backstop.
class FeeGate {
  FeeGate._();

  static const postTrip = 'POST_TRIP';
  static const acceptDeal = 'ACCEPT_DEAL';
  static const newChat = 'NEW_CHAT';

  static DateTime? _lastRefresh;
  static AppLifecycleListener? _lifecycle;

  /// Re-reads the profile on every return to the app, so a balance paid on
  /// the web (or verified by an admin) lifts the restriction without a restart.
  static void watch() {
    _lifecycle ??= AppLifecycleListener(onResume: () => refresh());
  }

  /// Fresh `/auth/user`, at most once every 30s unless [force]d.
  static Future<void> refresh({bool force = false}) async {
    final session = Get.find<SessionService>();
    if (session.isGuest) return;
    final now = DateTime.now();
    if (!force &&
        _lastRefresh != null &&
        now.difference(_lastRefresh!) < const Duration(seconds: 30)) {
      return;
    }
    _lastRefresh = now;
    try {
      await AuthRepository().me();
    } catch (_) {
      // offline: keep the cached state rather than locking or unlocking blindly
    }
  }

  static bool blocks(String action) =>
      Get.find<SessionService>().user.value?.feeBlocks(action) ?? false;

  /// Lets [action] go ahead, or explains the restriction and offers the
  /// ledgers. Re-checks with the server first so a just-paid balance isn't
  /// held against the user.
  static Future<bool> allow(String action) async {
    if (!blocks(action)) return true;
    await refresh(force: true);
    if (!blocks(action)) return true;
    await showRestricted(action);
    return false;
  }

  /// The API refused with 403 LEDGER_OVERDUE — show the same explanation.
  /// Returns true when [e] was that refusal.
  static bool handle(AppException e, String action) {
    if (!isOverdue(e)) return false;
    refresh(force: true);
    showRestricted(action);
    return true;
  }

  /// [e] is the API's overdue-ledger refusal (403 LEDGER_OVERDUE).
  static bool isOverdue(AppException e) =>
      e is ServerException &&
      (e.code == 'LEDGER_OVERDUE' ||
          (e.statusCode == 403 && e.message.toLowerCase().contains('overdue')));

  static Future<void> showRestricted(String action) async {
    final ctx = Get.context;
    if (ctx == null) return;
    final what = switch (action) {
      postTrip => 'restricted_to_post_trips'.tr,
      acceptDeal => 'restricted_to_accept_deals'.tr,
      _ => 'restricted_to_start_chats'.tr,
    };
    final go = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text('account_restricted'.tr),
        content: Text('account_restricted_body'.trParams({'action': what})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('close'.tr)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('settle_balance'.tr)),
        ],
      ),
    );
    if (go == true) Get.to(() => const FeeLedgersPage());
  }
}

/// Wraps the app shell: a warning strip across the top while a fee ledger is
/// overdue, tapping through to the ledgers. Gone the moment the profile says
/// the restriction lifted.
class FeeRestrictionScope extends StatelessWidget {
  final Widget child;
  const FeeRestrictionScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    return Obx(() {
      final user = session.user.value;
      if (user == null || !user.feeRestricted) return child;
      final currencies = user.overdueCurrencies;
      return Column(
        children: [
          Material(
            color: const Color(0xFFB45309),
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: () => Get.to(() => const FeeLedgersPage()),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          currencies.isEmpty
                              ? 'overdue_banner'.tr
                              : 'overdue_banner_with_ledgers'
                                  .trParams({'ledgers': currencies.join(' · ')}),
                          style: TextStyle(color: Colors.white, fontSize: 12.sp, height: 1.3),
                        ),
                      ),
                      Text('pay_now'.tr,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // the strip already took the status-bar inset — don't pad twice
          Expanded(
            child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
          ),
        ],
      );
    });
  }
}
