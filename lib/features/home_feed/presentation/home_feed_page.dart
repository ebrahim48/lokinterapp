import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/chat_gate.dart';
import '../../auth/presentation/login_page.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../core/widgets/lokinter_logo.dart';
import '../../../core/widgets/section_title.dart';
import '../../notifications/presentation/notifications_page.dart';
import '../../posts/presentation/post_details_page.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../../recommended/presentation/recommended_page.dart';
import '../../search_results/presentation/search_results_page.dart';
import 'controllers/home_feed_controller.dart';
import 'widgets/home_banner.dart';
import 'widgets/recommended_rail.dart';

class HomeFeedPage extends StatelessWidget {
  const HomeFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(HomeFeedController());

    return Scaffold(
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
          const LanguageSelector(compact: true),
          SizedBox(width: 4.w),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: c.load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
          children: [
            Obx(() => BannerCarousel(banners: c.banners.toList())),
            SizedBox(height: 20.h),
            SectionTitle(
              title: 'Recommended Travelers',
              onSeeAll: () => Get.to(() => const RecommendedPage()),
            ),
            SizedBox(height: 12.h),
            Obx(() {
              if (c.isGuest) return const _LoginNudge();
              if (c.loading.value && c.recommended.isEmpty) return const _RailShimmer();
              if (c.recommended.isEmpty) return const _EmptyNote(text: 'No travelers right now');
              return RecommendedRail(travelers: c.recommended.toList());
            }),
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
            Obx(() {
              if (c.isGuest) return const SizedBox.shrink();
              if (c.loading.value && c.feed.isEmpty) return const _RailShimmer();
              if (c.error.value != null && c.feed.isEmpty) {
                return _EmptyNote(text: c.error.value!);
              }
              if (c.feed.isEmpty) return const _EmptyNote(text: 'No deals posted yet');
              return Column(
                children: [
                  for (final post in c.feed) ...[
                    PostCard(
                      post: post,
                      onTap: () => Get.to(() => PostDetailsPage(post: post)),
                      onChat: () => openChat(post.user, postId: post.id),
                    ),
                    SizedBox(height: 14.h),
                  ],
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// what guests see instead of the account-only sections
class _LoginNudge extends StatelessWidget {
  const _LoginNudge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: AppPalette.primary, size: 22.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Log in to see recommended travelers and the latest deals.',
              style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: () => Get.to(() => const LoginPage()),
            child: const Text('Login', style: TextStyle(color: AppPalette.primary)),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 18.h),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12.5.sp, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _RailShimmer extends StatelessWidget {
  const _RailShimmer();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: cs.surfaceContainerHighest,
      highlightColor: cs.surface,
      // clipped scroll view so the placeholders can never overflow the row
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: List.generate(
            2,
            (_) => Container(
              width: 160.w,
              height: 110.h,
              margin: EdgeInsets.only(right: 12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
          ),
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
