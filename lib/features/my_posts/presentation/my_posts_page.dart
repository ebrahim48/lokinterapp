import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/lok_segmented.dart';
import '../../post_request/presentation/post_request_page.dart';
import '../../post_trip/presentation/post_trip_page.dart';
import '../../posts/data/mock_data.dart';
import '../../posts/data/models/post_model.dart';
import '../../posts/presentation/widgets/post_card.dart';

// Trips and requests the user has posted, with edit / delete.
class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  int _tab = 0; // 0 = Trips, 1 = Requests
  late final List<Post> _trips = [...MockData.trips];
  late final List<Post> _requests = [...MockData.requests];

  List<Post> get _items => _tab == 0 ? _trips : _requests;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My requests & trips')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
            child: LokSegmented(
              labels: const ['Trips', 'Requests'],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? _empty(context)
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => SizedBox(height: 16.h),
                    itemBuilder: (_, i) => _postWithActions(_items[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _postWithActions(Post post) {
    return Column(
      children: [
        PostCard(post: post, showChat: false, showUser: false),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Get.to(() =>
                    post.isTrip ? const PostTripPage() : const PostRequestPage()),
                icon: Icon(Icons.edit_outlined, size: 16.sp),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(minimumSize: Size(0, 42.h)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(post),
                icon: Icon(Icons.delete_outline, size: 16.sp, color: AppPalette.primary),
                label: const Text('Delete', style: TextStyle(color: AppPalette.primary)),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(0, 42.h),
                  side: const BorderSide(color: AppPalette.primary),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmDelete(Post post) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This will remove it from search results.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              setState(() => _items.remove(post));
            },
            child: const Text('Delete', style: TextStyle(color: AppPalette.primary)),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.post_add, size: 48.sp, color: cs.onSurfaceVariant),
          SizedBox(height: 12.h),
          Text('Nothing posted yet',
              style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
