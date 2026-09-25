import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/utils/chat_gate.dart';
import '../../posts/presentation/post_details_page.dart';
import '../../posts/presentation/widgets/post_card.dart';
import 'recommended_travelers_controller.dart';

// "See all" from the home rail — recommended travelers with active trips.
// Has its own controller that calls GET /api/v1/visibility/recommended-travelers
// directly, so the list is not limited to the handful pre-fetched by the home feed.
class RecommendedPage extends StatelessWidget {
  const RecommendedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Scoped to this route; disposed automatically when the user pops back.
    final c = Get.put(RecommendedTravelersController());

    return Scaffold(
      appBar: AppBar(title: Text('recommended_travelers_2'.tr)),
      body: RefreshIndicator(
        onRefresh: c.refresh,
        child: Obx(() {
          // ── Loading ──────────────────────────────────────────────────────
          if (c.state.value == RecommendedLoadState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          // ── Offline / Error with no cached data ──────────────────────────
          if (c.state.value == RecommendedLoadState.offline && c.travelers.isEmpty) {
            return _CenteredMessage(
              icon: Icons.wifi_off_outlined,
              message: 'no_internet_connection'.tr,
              onRetry: c.refresh,
            );
          }

          if (c.state.value == RecommendedLoadState.error && c.travelers.isEmpty) {
            return _CenteredMessage(
              icon: Icons.error_outline,
              message: c.errorMessage.value.isNotEmpty
                  ? c.errorMessage.value
                  : 'something_went_wrong'.tr,
              onRetry: c.refresh,
            );
          }

          // ── Loaded (or stale-cache while refreshing) ─────────────────────
          final trips = c.travelers.toList();

          return ListView(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
            children: [
              Text(
                'recommended_travelers_and_transporters_with_acti'.tr,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16.h),
              if (trips.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 40.h),
                  child: Center(
                    child: Text(
                      'no_recommended_travelers_right_now'.tr,
                      style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              for (final post in trips) ...[
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
      ),
    );
  }
}

// ── Private helper widget ────────────────────────────────────────────────────

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  const _CenteredMessage({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48.sp, color: cs.onSurfaceVariant),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
            ),
            SizedBox(height: 16.h),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text('retry'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
