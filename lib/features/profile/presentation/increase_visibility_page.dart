import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_palette.dart';
import '../data/profile_mock.dart';

// Replaces the old "Invoices & QR Codes" entry. Lets travelers/transporters
// apply to be recommended to relevant senders.
class IncreaseVisibilityPage extends StatelessWidget {
  const IncreaseVisibilityPage({super.key});

  static const _conditions = [
    'At least 3 successful deliveries',
    'No disputes on completed deliveries',
    'Identity documents verified',
    'Phone number verified',
  ];

  @override
  Widget build(BuildContext context) {
    const p = currentProfile;
    final cs = Theme.of(context).colorScheme;
    final eligible = p.eligibleForRecommended;

    return Scaffold(
      appBar: AppBar(title: const Text('Increase Visibility')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        children: [
          Text(
            'Get recommended to senders connected to your trip routes and show up '
            'higher in search.',
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.5),
          ),
          SizedBox(height: 20.h),
          _planCard(
            context,
            title: 'Recommended Traveler',
            price: 'Free',
            blurb: 'For travelers who meet all the conditions below.',
            child: Column(
              children: [
                for (final cdn in _conditions) _condition(context, cdn, true),
                SizedBox(height: 14.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: eligible ? () {} : null,
                    child: Text(eligible ? 'Apply now' : 'Not eligible yet'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          _planCard(
            context,
            title: 'Recommended Transporter',
            price: 'USD 22.99 / month',
            blurb: 'For transporters who want premium placement while subscribed.',
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Apply & subscribe'),
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
