import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/notify.dart';
import '../../lookups/data/lookups_repository.dart';
import '../data/visibility_repository.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/stripe_sheet.dart';
import 'controllers/profile_controller.dart';

// Replaces the old "Invoices & QR Codes" entry. Lets travelers/transporters
// apply to be recommended to relevant senders.
//
// NOTE: subscriptions are feature-flagged OFF on the website build
// (`subscriptionFeatureEnabled=false`), so "Apply & subscribe" stays a
// notice here too — but the plan price is now the live one from
// /lookups/getAllPlans instead of a hardcoded figure.
class IncreaseVisibilityPage extends StatefulWidget {
  const IncreaseVisibilityPage({super.key});

  @override
  State<IncreaseVisibilityPage> createState() => _IncreaseVisibilityPageState();
}

class _IncreaseVisibilityPageState extends State<IncreaseVisibilityPage> {
  final _visibility = VisibilityRepository();
  final _storage = Get.find<StorageService>();
  String? _planPrice;
  bool _busy = false;

  // /auth/user doesn't report a pending traveler application, so remember it
  // per account; an approved one is visible through the badge fields instead
  String get _appliedKey =>
      'recommended_applied_${Get.find<SessionService>().user.value?.id ?? 0}';
  bool get _alreadyApplied =>
      (_storage.getBool(_appliedKey) ?? false) ||
      (Get.find<SessionService>().user.value?.isFeaturedTransporter ?? false);

  @override
  void initState() {
    super.initState();
    LookupsRepository().plans().then((plans) {
      if (!mounted || plans.isEmpty) return;
      // first paid plan drives the transporter card's price line
      final paid = plans.firstWhereOrNull(
          (p) => (double.tryParse('${p['price'] ?? 0}') ?? 0) > 0);
      if (paid != null) {
        final unit = (paid['unit'] ?? 'month').toString().toLowerCase();
        setState(() => _planPrice = 'USD ${paid['price']} / $unit');
      }
    }).catchError((_) {});
  }

  // free application — the server re-checks eligibility before accepting
  Future<void> _applyTraveler() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await _visibility.applyTraveler();
      await _storage.setBool(_appliedKey, true);
      final approved = res['isAutoApproved'] == true;
      toast(approved
          ? 'application_approved'.tr
          : 'application_received_the_team_will_review_it'.tr);
      await _refreshUser();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // \$22.99 / 30 days; on success the account carries the recommended badge
  Future<void> _subscribeTransporter() async {
    if (_busy) return;
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('recommended_transporter'.tr),
        content: Text('subscribe_confirm_body'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
          ElevatedButton(
              onPressed: () => Get.back(result: true), child: Text('continue'.tr)),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final res = await _visibility.subscribeTransporter();

      // when the backend opens a Stripe intent, charge the card the same way
      // escrow does; otherwise it settled the payment itself
      final secret = clientSecretOf(res);
      if (secret.isNotEmpty) {
        final paid = await presentStripeSheet(secret);
        if (!paid) return; // cancelled — leave the subscription untouched
        final intentId = '${res['paymentIntentId'] ?? ''}';
        if (intentId.isNotEmpty) {
          try {
            await _visibility.confirmTransporterSubscription(intentId);
          } on AppException {
            // a webhook-driven backend has no confirm step; the refresh below
            // still picks up the activated subscription
          }
        }
      }

      final until = '${res['featuredUntil'] ?? ''}';
      toast(until.isEmpty
          ? 'subscription_activated'.tr
          : 'subscription_active_until'.trParams({'date': until.split(' ').first}));
      await _refreshUser();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // re-reads /auth/user so the subscription and badges reflect the new state
  Future<void> _refreshUser() async {
    if (Get.isRegistered<ProfileController>()) {
      await Get.find<ProfileController>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('increase_visibility'.tr)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        children: [
          Text(
            'Get recommended to senders connected to your trip routes and show up '
            'higher in search.',
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.5),
          ),
          SizedBox(height: 20.h),
          Obx(() {
            // every condition now comes straight from /auth/user
            final u = c.user;
            final deliveriesOk = u?.hasThreeDeliveries ?? false;
            final noDisputesOk = u?.hasNoDisputes ?? false;
            final idOk = u?.identityVerified ?? false;
            final phoneOk = u?.phoneVerified ?? false;
            final eligible = u?.canApplyRecommendedTraveler ?? false;

            return _planCard(
              context,
              title: 'recommended_traveler'.tr,
              price: 'Free',
              blurb: 'For travelers who meet all the conditions below.',
              child: Column(
                children: [
                  _condition(
                      context,
                      'at_least_3_successful_deliveries'.tr,
                      deliveriesOk,
                      // show progress while they're still short of three
                      trailing: deliveriesOk
                          ? null
                          : '${u?.successfulDeliveriesCount ?? 0}/3'),
                  _condition(context, 'no_disputes_on_completed_deliveries'.tr,
                      noDisputesOk),
                  _condition(context, 'identity_documents_verified'.tr, idOk),
                  _condition(context, 'phone_number_verified_2'.tr, phoneOk),
                  SizedBox(height: 14.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (eligible && !_busy && !_alreadyApplied)
                          ? _applyTraveler
                          : null,
                      child: Text(_alreadyApplied
                          ? 'already_applied'.tr
                          : eligible
                              ? 'apply_now'.tr
                              : 'not_eligible_yet'.tr),
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 16.h),
          Obx(() {
            final u = c.user;
            final subscribed = u?.hasActiveSubscription ?? false;
            final until = u?.subscriptionEndsOn;
            return _planCard(
              context,
              title: 'recommended_transporter'.tr,
              price: _planPrice ?? 'USD 22.99 / month',
              blurb: 'For transporters who want premium placement while subscribed.',
              child: Column(
                children: [
                  if (subscribed) ...[
                    _condition(
                      context,
                      until == null
                          ? 'you_are_already_subscribed'.tr
                          : 'subscription_active_until'.trParams({'date': until}),
                      true,
                    ),
                    SizedBox(height: 4.h),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed:
                          (_busy || subscribed) ? null : _subscribeTransporter,
                      child: Text(subscribed
                          ? 'you_are_already_subscribed'.tr
                          : 'apply_subscribe'.tr),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _planCard(BuildContext context,
      {required String title, required String price, required String blurb, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
              ),
              SizedBox(width: 10.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(price,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.sp, color: AppPalette.primary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(blurb, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, height: 1.4)),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }

  Widget _condition(BuildContext context, String text, bool met,
      {String? trailing}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 17.sp, color: met ? AppPalette.verified : cs.onSurfaceVariant),
          SizedBox(width: 10.w),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.sp, color: cs.onSurface))),
          if (trailing != null)
            Text(trailing,
                style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
