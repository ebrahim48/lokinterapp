import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../posts/data/mock_data.dart';
import '../../posts/presentation/post_details_page.dart';
import '../../posts/presentation/widgets/post_card.dart';

// "See all" from the home rail — only recommended travelers/transporters with active trips.
class RecommendedPage extends StatelessWidget {
  const RecommendedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trips = MockData.recommendedActiveTrips;

    return Scaffold(
      appBar: AppBar(title: const Text('Recommended travelers')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        children: [
          Text(
            'Recommended travelers and transporters with active trips on your routes.',
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.4),
          ),
          SizedBox(height: 16.h),
          for (final post in trips) ...[
            PostCard(post: post, onTap: () => Get.to(() => PostDetailsPage(post: post))),
            SizedBox(height: 14.h),
          ],
        ],
      ),
    );
  }
}
