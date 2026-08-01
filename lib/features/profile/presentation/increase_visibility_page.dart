import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/notify.dart';
import '../../lookups/data/lookups_repository.dart';
import '../data/visibility_repository.dart';
import '../../../core/exceptions/app_exceptions.dart';
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
  String? _planPrice;
  bool _busy = false;

  // free application — the server re-checks eligibility before accepting
  Future<void> _applyTraveler() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _visibility.applyTraveler();
      toast('application_received_the_team_will_review_it'.tr);
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
      final until = '${res['featuredUntil'] ?? ''}';
      toast(until.isEmpty
          ? 'subscription_activated'.tr
          : 'subscription_active_until'.trParams({'date': until.split(' ').first}));
      // refresh the session so the badge appears straight away
      if (Get.isRegistered<ProfileController>()) {
        await Get.find<ProfileController>().load();
      }
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
            final summary = c.summary.value;
            final idOk = c.user?.identityVerified ?? false;
            final phoneOk = summary?.phoneVerified ?? false;
            final deliveriesOk = (summary?.completedDeals ?? 0) >= 3;
            final eligible = idOk && phoneOk && deliveriesOk;

            return _planCard(
              context,
              title: 'recommended_traveler'.tr,
              price: 'Free',
              blurb: 'For travelers who meet all the conditions below.',
              child: Column(
                children: [
                  _condition(context, 'At least 3 successful deliveries', deliveriesOk),
                  _condition(context, 'No disputes on completed deliveries', deliveriesOk),
                  _condition(context, 'Identity documents verified', idOk),
                  _condition(context, 'Phone number verified', phoneOk),
                  SizedBox(height: 14.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (eligible && !_busy) ? _applyTraveler : null,
                      child: Text(eligible ? 'apply_now'.tr : 'not_eligible_yet'.tr),
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 16.h),
          _planCard(
            context,
            title: 'recommended_transporter'.tr,
            price: _planPrice ?? 'USD 22.99 / month',
            blurb: 'For transporters who want premium placement while subscribed.',
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _subscribeTransporter,
                child: Text('apply_subscribe'.tr),
              ),
            ),
          ),
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

  Widget _condition(BuildContext context, String text, bool met) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 17.sp, color: met ? AppPalette.verified : cs.onSurfaceVariant),
          SizedBox(width: 10.w),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.sp, color: cs.onSurface))),
        ],
      ),
    );
  }
}
