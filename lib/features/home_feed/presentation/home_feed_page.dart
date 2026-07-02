import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/section_title.dart';
import '../../notifications/presentation/notifications_page.dart';
import '../../post_request/presentation/post_request_page.dart';
import '../../post_trip/presentation/post_trip_page.dart';
import '../../posts/presentation/post_details_page.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../../posts/presentation/widgets/search_filter_sheet.dart';
import '../../search_results/presentation/search_results_page.dart';
import 'controllers/home_feed_controller.dart';
import 'widgets/app_drawer.dart';
import 'widgets/home_banner.dart';
import 'widgets/recommended_rail.dart';

class HomeFeedPage extends StatelessWidget {
  const HomeFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(HomeFeedController());

    return Scaffold(
      endDrawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('LOKINTER'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: () => Get.changeThemeMode(
              Get.isDarkMode ? ThemeMode.light : ThemeMode.dark,
            ),
            icon: Icon(Get.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Get.to(() => const NotificationsPage()),
            icon: const Icon(Icons.notifications_none),
          ),
          Builder(
            builder: (ctx) => IconButton(
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              icon: const Icon(Icons.menu),
            ),
          ),
          SizedBox(width: 4.w),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppPalette.primary,
        onPressed: () => _openPostSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 90.h),
        children: [
          const HomeBanner(),
          SizedBox(height: 22.h),
          SectionTitle(
            title: 'Recommended Travelers',
            onSeeAll: () => Get.to(() => const SearchResultsPage(), arguments: 0),
          ),
          SizedBox(height: 12.h),
          RecommendedRail(travelers: c.recommended),
          SizedBox(height: 22.h),
          Row(
            children: [
              Expanded(
                child: _BrowseTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'Requests',
                  color: AppPalette.primary,
                  onTap: () => Get.to(() => const SearchResultsPage(), arguments: 1),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _BrowseTile(
                  icon: Icons.flight_takeoff,
                  label: 'Trips',
                  color: AppPalette.intlAccent,
                  onTap: () => Get.to(() => const SearchResultsPage(), arguments: 0),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _SearchBar(onTap: () => SearchFilterSheet.show(context)),
          SizedBox(height: 22.h),
          const SectionTitle(title: 'Latest deals'),
          SizedBox(height: 12.h),
          for (final post in c.feed) ...[
            PostCard(post: post, onTap: () => Get.to(() => PostDetailsPage(post: post))),
            SizedBox(height: 14.h),
          ],
        ],
      ),
    );
  }

  void _openPostSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
            SizedBox(height: 8.h),
            ListTile(
              leading: const Icon(Icons.flight_takeoff, color: AppPalette.intlAccent),
              title: const Text('Post a Trip'),
              onTap: () {
                Get.back();
                Get.to(() => const PostTripPage());
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: AppPalette.primary),
              title: const Text('Post a delivery request'),
              onTap: () {
                Get.back();
                Get.to(() => const PostRequestPage());
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}

class _BrowseTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BrowseTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22.sp),
            SizedBox(width: 10.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 20.sp, color: cs.onSurfaceVariant),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'Where do you want to send?',
                style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
              ),
            ),
            Icon(Icons.tune, size: 20.sp, color: AppPalette.primary),
          ],
        ),
      ),
    );
  }
}
