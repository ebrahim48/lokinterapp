import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/format.dart';
import '../../data/deal_model.dart';
import 'deal_countdown.dart';
import 'status_badge.dart';
import 'package:get/get.dart';
import '../deals_controller.dart';
import '../../../posts/presentation/widgets/transporter_chip.dart';

class DealCard extends StatelessWidget {
  final Deal deal;
  final VoidCallback? onTap;

  const DealCard({super.key, required this.deal, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show transporter badge if the counterpart is an approved transporter
            if (deal.counterpart.isTransporter) ...[
              TransporterChip(recommended: false),
              SizedBox(height: 8.h),
            ],
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16.sp, color: AppPalette.primary),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    '${deal.fromCountry} → ${deal.toCountry}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                StatusBadge(status: deal.status),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                _meta(context, deal.isLocal ? Icons.location_on : Icons.flight,
                    deal.isLocal ? 'local'.tr : 'international'.tr),
                SizedBox(width: 16.w),
                _meta(context, Icons.event_outlined, shortDate(deal.date)),
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Icon(Icons.payments_outlined, size: 15.sp, color: AppPalette.verified),
                SizedBox(width: 6.w),
                Text(
                  deal.profitLabel,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.verified,
                  ),
                ),
                const Spacer(),
                Text('#${deal.id}',
                    style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
              ],
            ),
            // disputed deals lead with the dispute itself
            if (deal.hasDisputeRecord) ...[
              SizedBox(height: 10.h),
              _disputeLine(context),
            ],
            if (deal.status == DealStatus.completed && deal.isAutoCompleted) ...[
              SizedBox(height: 10.h),
              const AutoCompletedChip(),
            ],
            // completed deals: time left to open a dispute
            if (deal.disputeWindowEndsAt != null) ...[
              SizedBox(height: 10.h),
              DealCountdown(
                endsAt: deal.disputeWindowEndsAt!,
                window: DealWindow.dispute,
                compact: true,
                onExpired: () {
                  if (Get.isRegistered<DealsController>()) {
                    Get.find<DealsController>().load();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _disputeLine(BuildContext context) {
    final (_, fg) = DealStatus.disputes.colors;
    final d = deal.disputeInfo ?? const <String, dynamic>{};
    final reason = '${d['reasonLabel'] ?? d['reason'] ?? ''}';
    final status = '${d['statusLabel'] ?? d['status'] ?? ''}';
    return Row(
      children: [
        Icon(Icons.gpp_maybe_outlined, size: 15.sp, color: fg),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            reason.isNotEmpty ? reason : 'dispute_report'.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: fg),
          ),
        ),
        if (status.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(status,
                style: TextStyle(fontSize: 9.5.sp, fontWeight: FontWeight.w700, color: fg)),
          ),
      ],
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14.sp, color: cs.onSurfaceVariant),
        SizedBox(width: 5.w),
        Text(text, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
      ],
    );
  }
}
