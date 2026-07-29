import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/chat_gate.dart';
import '../../../core/widgets/lok_segmented.dart';
import '../../auth/presentation/login_page.dart';
import '../../posts/presentation/post_details_page.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../../posts/presentation/widgets/search_filter_sheet.dart';
import 'controllers/search_results_controller.dart';

class SearchResultsPage extends StatelessWidget {
  const SearchResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SearchResultsController());
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('search_for_deals'.tr),
        actions: [
          IconButton(
            onPressed: () => SearchFilterSheet.show(context),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
            child: Obx(() => LokSegmented(
                  labels: const ['Trips', 'Requests'],
                  selected: c.tab.value,
                  onChanged: (i) => c.tab.value = i,
                )),
          ),
          Expanded(
            child: Obx(() {
              if (c.isGuest) return _guestNote(cs);
              if (c.loading.value && c.results.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (c.error.value != null && c.results.isEmpty) {
                return _message(cs, c.error.value!, retry: c.load);
              }
              if (c.results.isEmpty) {
                return _message(cs, 'Nothing matches your search yet');
              }
              return RefreshIndicator(
                onRefresh: c.load,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 300) c.loadMore();
                    return false;
                  },
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                    itemCount: c.results.length,
                    separatorBuilder: (_, __) => SizedBox(height: 14.h),
                    itemBuilder: (_, i) => PostCard(
                      post: c.results[i],
                      onTap: () => Get.to(() => PostDetailsPage(post: c.results[i])),
                      onChat: () =>
                          openChat(c.results[i].user, postId: c.results[i].id),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _guestNote(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 40.sp, color: cs.onSurfaceVariant),
          SizedBox(height: 12.h),
          Text(
            'log_in_to_browse_trips_and_requests'.tr,
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
          ),
          SizedBox(height: 12.h),
          TextButton(
            onPressed: () => Get.to(() => const LoginPage()),
            child: Text('login'.tr, style: TextStyle(color: AppPalette.primary)),
          ),
        ],
      ),
    );
  }

  Widget _message(ColorScheme cs, String text, {Future<void> Function()? retry}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
          if (retry != null) ...[
            SizedBox(height: 10.h),
            TextButton(
              onPressed: retry,
              child: Text('retry'.tr, style: TextStyle(color: AppPalette.primary)),
            ),
          ],
        ],
      ),
    );
  }
}
