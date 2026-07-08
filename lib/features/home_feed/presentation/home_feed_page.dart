import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/lokinter_logo.dart';
import '../../../core/widgets/section_title.dart';
import '../../notifications/presentation/notifications_page.dart';
import '../../posts/presentation/post_details_page.dart';
import '../../posts/presentation/widgets/post_card.dart';
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
        title: const LokinterLogo(fontSize: 20),
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
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
        children: [
          const HomeBanner(),
          SizedBox(height: 20.h),
          SectionTitle(
            title: 'Recommended Travelers',
            onSeeAll: () => Get.to(() => const SearchResultsPage(), arguments: 0),
          ),
          SizedBox(height: 12.h),
          RecommendedRail(travelers: c.recommended),
          SizedBox(height: 20.h),
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
          SizedBox(height: 20.h),
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
        padding: EdgeInsets.symmetric(vertical: 13.h, horizontal: 14.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
