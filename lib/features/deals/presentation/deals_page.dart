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
      appBar: AppBar(
        title: Text('deals'.tr),
        actions: [
          Obx(() => IconButton(
                tooltip: 'filter'.tr,
                onPressed: () => _openFilter(context, c),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.filter_list),
                    // a dot marks that a non-"All" filter is active
                    if (c.filter.value != null)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 8.r,
                          height: 8.r,
                          decoration: const BoxDecoration(
                              color: AppPalette.primary, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              )),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              children: [
                _chip(context, c, null, 'deals.all'.tr),
                for (final s in DealStatus.values) _chip(context, c, s, s.label),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (c.loading.value && c.deals.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (c.error.value != null && c.deals.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.error.value!,
                          style: TextStyle(
                              fontSize: 13.sp,
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      TextButton(onPressed: c.load, child: Text('retry'.tr)),
                    ],
                  ),
                );
              }
              if (c.deals.isEmpty) return _empty(context);
              return RefreshIndicator(
                onRefresh: c.load,
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                  itemCount: c.deals.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (_, i) => DealCard(
                    deal: c.deals[i],
                    onTap: () => Get.to(() => DealDetailsPage(deal: c.deals[i])),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _openFilter(BuildContext context, DealsController c) {
    final cs = Theme.of(context).colorScheme;
    final options = <(DealStatus?, String)>[
      (null, 'deals.all'.tr),
      for (final s in DealStatus.values) (s, s.label),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('filter_deals'.tr,
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
              ),
            ),
            for (final (status, label) in options)
              Obx(() {
                final active = c.filter.value == status;
                return ListTile(
                  onTap: () {
                    c.filter.value = status;
                    Navigator.pop(context);
                  },
                  title: Text(label,
                      style: TextStyle(
                          fontSize: 14.sp,
                          color: active ? AppPalette.primary : cs.onSurface,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                  trailing: active
                      ? const Icon(Icons.check, color: AppPalette.primary)
                      : null,
                );
              }),
            SizedBox(height: 8.h),
          ],
        ),
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
          Text('no_deals_here_yet'.tr,
              style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
