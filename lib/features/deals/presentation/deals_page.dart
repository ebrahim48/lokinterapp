import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../data/deal_model.dart';
import 'deal_details_page.dart';
import 'deals_controller.dart';
import 'widgets/deal_card.dart';

class DealsPage extends StatelessWidget {
  const DealsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(DealsController());

    return Scaffold(
      appBar: AppBar(title: const Text('Deals')),
      body: Column(
        children: [
          SizedBox(
            height: 44.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              children: [
                _chip(context, c, null, 'All'),
                for (final s in DealStatus.values) _chip(context, c, s, s.label),
              ],
            ),
          ),
          Expanded(
            child: Obx(
              () => c.deals.isEmpty
                  ? _empty(context)
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                      itemCount: c.deals.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.h),
                      itemBuilder: (_, i) => DealCard(
                        deal: c.deals[i],
                        onTap: () => Get.to(() => DealDetailsPage(deal: c.deals[i])),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, DealsController c, DealStatus? s, String label) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final active = c.filter.value == s;
      return Padding(
        padding: EdgeInsets.only(right: 8.w),
        child: GestureDetector(
          onTap: () => c.filter.value = s,
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: active ? AppPalette.primary : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: active ? AppPalette.primary : cs.outline),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _empty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48.sp, color: cs.onSurfaceVariant),
          SizedBox(height: 12.h),
          Text('No deals here yet',
              style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
