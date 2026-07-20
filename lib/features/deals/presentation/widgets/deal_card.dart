import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/format.dart';
import '../../data/deal_model.dart';
import 'status_badge.dart';

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
                    deal.isLocal ? 'Local' : 'International'),
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
          ],
        ),
      ),
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
