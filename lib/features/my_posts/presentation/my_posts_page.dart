import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/notify.dart';
import '../../../core/widgets/lok_segmented.dart';
import '../../post_request/presentation/post_request_page.dart';
import '../../post_trip/presentation/post_trip_page.dart';
import '../../posts/data/models/post_model.dart';
import '../../posts/data/posts_repository.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../../../core/services/data_bus.dart';

// Trips and requests the user has posted, with edit / delete.
class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  final _repo = PostsRepository();

  int _tab = 0; // 0 = Trips, 1 = Requests
  List<Post> _trips = [];
  List<Post> _requests = [];
  bool _loading = true;
  String? _error;

  List<Post> get _items => _tab == 0 ? _trips : _requests;

  @override
  void initState() {
    super.initState();
    _load();
    // a write elsewhere invalidates this list
    _busSub = DataBus.on({DataTopic.posts, DataTopic.deals}).listen((_) => _load());
  }

  StreamSubscription<DataTopic>? _busSub;

  @override
  void dispose() {
    _busSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _trips.isEmpty && _requests.isEmpty;
      _error = null;
    });
    try {
      final results = await Future.wait([_repo.myPosts('TRIP'), _repo.myPosts('DELIVER')]);
      if (!mounted) return;
      setState(() {
        _trips = results[0];
        _requests = results[1];
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_items.isEmpty) _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('my_requests_trips'.tr)),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
            child: LokSegmented(
              labels: ['trips'.tr, 'requests'.tr],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(fontSize: 13.sp)),
            TextButton(onPressed: _load, child: Text('retry'.tr)),
          ],
        ),
      );
    }
    if (_items.isEmpty) return _empty(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
        itemCount: _items.length,
        separatorBuilder: (_, __) => SizedBox(height: 16.h),
        itemBuilder: (_, i) => _postWithActions(_items[i]),
      ),
    );
  }

  Widget _postWithActions(Post post) {
    // the buttons sit inside the card; on the coral request card they go white
    final onCoral = !post.isTrip;
    final editColor = onCoral ? Colors.white : AppPalette.navy;
    final deleteColor = onCoral ? Colors.white : AppPalette.primary;
    final actions = Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final saved = await Get.to<bool>(() => post.isTrip
                  ? PostTripPage(editId: post.id)
                  : PostRequestPage(editId: post.id));
              if (saved == true) _load();
            },
            icon: Icon(Icons.edit_outlined, size: 16.sp, color: editColor),
            label: Text('edit'.tr, style: TextStyle(color: editColor)),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, 40.h),
              side: BorderSide(color: editColor.withValues(alpha: 0.35)),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _confirmDelete(post),
            icon: Icon(Icons.delete_outline, size: 16.sp, color: deleteColor),
            label: Text('delete'.tr, style: TextStyle(color: deleteColor)),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, 40.h),
              side: BorderSide(color: deleteColor),
            ),
          ),
        ),
      ],
    );
    return PostCard(
        post: post, showChat: false, showUser: false, footer: actions);
  }

  void _confirmDelete(Post post) {
    Get.dialog(
      AlertDialog(
        title: Text('delete_post'.tr),
        content: Text('this_will_remove_it_from_search_results'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () async {
              Get.back();
              try {
                await _repo.deletePost(post.id);
                if (!mounted) return;
                setState(() => _items.remove(post));
                toast('post_deleted'.tr);
              } on AppException catch (e) {
                toastError(e);
              }
            },
            child: Text('delete'.tr, style: TextStyle(color: AppPalette.primary)),
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
          Text('nothing_posted_yet'.tr,
              style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
