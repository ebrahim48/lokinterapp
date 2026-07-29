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
import '../../notifications/presentation/notifications_badge_controller.dart';

class HomeFeedPage extends StatelessWidget {
  const HomeFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(HomeFeedController());
    final nb = Get.put(NotificationsBadgeController(), permanent: true);

    return Scaffold(
      appBar: AppBar(
        title: const LokinterLogo(fontSize: 20),
        actions: [
          IconButton(
            tooltip: 'toggle_theme'.tr,
            onPressed: () => Get.changeThemeMode(
              Get.isDarkMode ? ThemeMode.light : ThemeMode.dark,
            ),
            icon: Icon(Get.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
          // bell carries the unread count so new activity is visible at a glance
          Obx(() {
            final n = nb.unread.value;
            return IconButton(
              tooltip: 'notifications'.tr,
              onPressed: () async {
                await Get.to(() => const NotificationsPage());
                nb.refreshCount();
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none),
                  if (n > 0)
                    Positioned(
                      right: -3.w,
                      top: -3.h,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                        constraints: BoxConstraints(minWidth: 14.w),
                        decoration: BoxDecoration(
                          color: AppPalette.primary,
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          n > 99 ? '99+' : '$n',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
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
              title: 'recommended_travelers'.tr,
              onSeeAll: () => Get.to(() => const RecommendedPage()),
            ),
            SizedBox(height: 12.h),
            Obx(() {
              // touch an observable before any early return, otherwise this Obx
              // tracks nothing on the guest branch and GetX throws
              final loading = c.loading.value;
              if (c.isGuest) return const _LoginNudge();
              if (loading && c.recommended.isEmpty) return const _RailShimmer();
              if (c.recommended.isEmpty) {
                return _EmptyNote(text: 'no_recommended_travelers_right_now'.tr);
              }
              return RecommendedRail(
                travelers: c.recommended.toList(),
                onTap: (post) => Get.to(() => PostDetailsPage(post: post)),
              );
            }),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: _BrowseTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'requests'.tr,
                    color: AppPalette.primary,
                    onTap: () => Get.to(() => const SearchResultsPage(), arguments: 1),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _BrowseTile(
                    icon: Icons.flight_takeoff,
                    label: 'trips'.tr,
                    color: AppPalette.intlAccent,
                    onTap: () => Get.to(() => const SearchResultsPage(), arguments: 0),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            SectionTitle(title: 'latest_posts'.tr),
            SizedBox(height: 12.h),
            Obx(() {
              final posts = c.visibleFeed; // tracked before any early return
              if (c.isGuest) return const SizedBox.shrink();
              if (c.loading.value && posts.isEmpty) return const _RailShimmer();
              if (c.error.value != null && posts.isEmpty) {
                return _EmptyNote(text: c.error.value!);
              }
              if (posts.isEmpty) return const _EmptyNote(text: 'Nothing posted yet');
              return Column(
                children: [
                  for (final post in posts) ...[
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
              'log_in_to_see_recommended_travelers_and_the_late'.tr,
              style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: () => Get.to(() => const LoginPage()),
            child: Text('login'.tr, style: TextStyle(color: AppPalette.primary)),
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

