import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/utils/chat_gate.dart';
import '../../home_feed/presentation/controllers/home_feed_controller.dart';
import '../../posts/presentation/post_details_page.dart';
import '../../posts/presentation/widgets/post_card.dart';

// "See all" from the home rail — recommended travelers with active trips.
class RecommendedPage extends StatelessWidget {
  const RecommendedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final home = Get.find<HomeFeedController>();

    return Scaffold(
      appBar: AppBar(title: Text('recommended_travelers_2'.tr)),
      body: Obx(() {
        final trips = home.recommended.toList();
        return ListView(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          children: [
            Text(
              'recommended_travelers_and_transporters_with_acti'.tr,
              style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.4),
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
    );
  }
}
