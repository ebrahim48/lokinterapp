import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/role_rules.dart';
import '../../../fees/presentation/fee_ledgers_page.dart';
import '../../data/deal_model.dart';

/// The transporter's platform fee on a completed deal (REQ §7, §8, §12 ·
/// GUIDE Screen 8). Ordinary travelers see they're exempt; professional
/// carriers see the fee, its tier and how far the next cheaper tier is. A fee
/// still waiting on a dispute or verification says so instead of a number.
class PlatformFeeCard extends StatelessWidget {
  final Deal deal;
  const PlatformFeeCard({super.key, required this.deal});

  @override
  Widget build(BuildContext context) {
    final fee = deal.extras.platformFee;
    final professional = isVerifiedTransporter;
    // nothing to say yet for a carrier whose fee the API hasn't attached
    if (fee == null && professional) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final exempt = fee == null || !fee.applies;
    final currency = deal.isLocal ? 'TND' : 'USD';

    final String headline;
    if (exempt) {
      headline = 'platform_fee_exempt'.trParams({
        'amount': formatFee(0, currency),
      });
    } else if (fee.isPending) {
      headline = 'platform_fee_pending'.tr;
    } else {
      final tier = fee.tierLabel;
      headline = tier.isEmpty
          ? 'platform_fee_amount'.trParams({'amount': fee.amountLabel})
          : 'platform_fee_amount_tier'.trParams({
              'amount': fee.amountLabel,
              'tier': tier,
            });
    }

    final progress =
        !exempt &&
            !fee.isPending &&
            fee.nextRate != null &&
            fee.dealsToNextTier != null
        ? (fee.isLocal ? 'next_tier_this_month' : 'next_tier_90_days')
              .trParams({
                'n': '${fee.dealsToNextTier}',
                'rate': formatFee(
                  fee.nextRate,
                  fee.currency.isEmpty ? currency : fee.currency,
                ),
              })
        : null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_outlined,
                size: 18.sp,
                color: AppPalette.primary,
              ),
              SizedBox(width: 8.w),
              Text(
                'platform_fee'.tr,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            headline,
            style: TextStyle(
              fontSize: 13.sp,
              color: cs.onSurface,
              height: 1.35,
            ),
          ),
          if (progress != null) ...[
            SizedBox(height: 10.h),
            if (fee!.tierTo != null &&
                fee.periodCount != null &&
                fee.tierFrom != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: LinearProgressIndicator(
                  value:
                      ((fee.periodCount! - fee.tierFrom! + 1) /
                              (fee.tierTo! - fee.tierFrom! + 1))
                          .clamp(0, 1)
                          .toDouble(),
                  minHeight: 6.h,
                  color: AppPalette.primary,
                  backgroundColor: cs.outline.withValues(alpha: 0.4),
                ),
              ),
            SizedBox(height: 6.h),
            Text(
              progress,
              style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
            ),
          ],
          if (!exempt) ...[
            SizedBox(height: 6.h),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Get.to(() => const FeeLedgersPage()),
                child: Text('view_fee_ledgers'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
