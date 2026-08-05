import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/chat_gate.dart';
import '../../../core/utils/notify.dart';
import '../../post_request/presentation/post_request_page.dart';
import '../../post_trip/presentation/post_trip_page.dart';
import '../../reviews/presentation/user_reviews_page.dart';
import '../data/models/post_model.dart';
import '../data/posts_repository.dart';
import 'widgets/mode_badge.dart';
import 'widgets/transporter_chip.dart';
import '../../../core/widgets/image_viewer.dart';

class PostDetailsPage extends StatelessWidget {
  final Post post;
  const PostDetailsPage({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final buy = post.wantTo == WantTo.buyAndDeliver;

    return Scaffold(
      appBar: AppBar(title: Text(post.isTrip ? 'Trip' : 'Delivery request')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        children: [
          // the request's item picture — tap to open it full screen
          if (!post.isTrip)
            GestureDetector(
              onTap: post.imageUrl == null
                  ? null
                  : () => ImageViewerPage.open(context, post.imageUrl!,
                      title: post.title),
              child: Container(
                height: 180.h,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: cs.outline),
                ),
                child: post.imageUrl == null
                    ? Icon(Icons.image_outlined, size: 56.sp, color: cs.onSurfaceVariant)
                    : Image.network(
                        post.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Icon(Icons.image_outlined,
                            size: 56.sp, color: cs.onSurfaceVariant),
                      ),
              ),
            ),
          if (!post.isTrip) SizedBox(height: 16.h),
          _routeCard(context),
          if (!post.isTrip) ...[
            SizedBox(height: 16.h),
            Text(buy ? 'Buy for me and deliver' : 'Deliver ready item',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
            if (post.title != null) ...[
              SizedBox(height: 4.h),
              Text(post.title!, style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
            ],
          ],
          SizedBox(height: 16.h),
          _metaList(context),
          SizedBox(height: 16.h),
          _userCard(context),
          SizedBox(height: 20.h),
          ..._actions(context),
        ],
      ),
    );
  }

  // Own posts get manage actions; everyone else's get the chat CTA, so the
  // screen always ends in something actionable.
  List<Widget> _actions(BuildContext context) {
    final isMine = post.mine(Get.find<SessionService>().user.value?.id);

    if (isMine) {
      return [
        ElevatedButton.icon(
          onPressed: () => Get.to(() => post.isTrip
              ? PostTripPage(editId: post.id)
              : PostRequestPage(editId: post.id)),
          icon: const Icon(Icons.edit_outlined),
          label: Text(post.isTrip ? 'Edit this trip' : 'Edit this request'),
        ),
        SizedBox(height: 12.h),
        OutlinedButton.icon(
          onPressed: () => _confirmDelete(context),
          icon: Icon(Icons.delete_outline, size: 18.sp, color: AppPalette.primary),
          label: Text('delete'.tr, style: TextStyle(color: AppPalette.primary)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppPalette.primary)),
        ),
      ];
    }

    return [
      ElevatedButton.icon(
        onPressed: () => openChat(post.user, postId: post.id),
        icon: const Icon(Icons.chat_bubble_outline),
        label: Text(post.isTrip
            ? 'Chat with ${post.user.name}'
            : 'Chat about this request'),
      ),
    ];
  }

  void _confirmDelete(BuildContext context) {
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
                await PostsRepository().deletePost(post.id);
                Get.back(); // leave the details screen too
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

  Widget _routeCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Expanded(child: _end(context, 'FROM', post.from, false)),
          ModeBadge(location: post.location, place: post.from, iso: post.flagIso),
          Expanded(child: _end(context, 'TO', post.to, true)),
        ],
      ),
    );
  }

  Widget _end(BuildContext context, String label, String value, bool end) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9.sp, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
        SizedBox(height: 3.h),
        Text(value,
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
      ],
    );
  }

  Widget _metaList(BuildContext context) {
    final rows = <(IconData, String, String)>[
      (Icons.event_outlined, post.isTrip ? 'Trip date' : 'Before', post.dateText),
      (Icons.luggage_outlined, 'Weight', post.weightDetailText),
      // every category the sender picked, not just the first
      if (!post.isTrip && post.categoriesText.isNotEmpty)
        (Icons.category_outlined, 'Category', post.categoriesText),
      // trips list what they won't carry
      if (post.isTrip && post.rejectedCategories.isNotEmpty)
        (Icons.block_outlined, 'Not carried', post.rejectedCategories.join(', ')),
      if (!post.isTrip && post.profitText != null)
        (Icons.payments_outlined, 'Traveler profit', post.profitText!),
      // whatever the poster typed in the notes box
      if ((post.notes ?? '').isNotEmpty)
        (Icons.notes_outlined, 'Notes', post.notes!),
    ];
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: cs.outline),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(rows[i].$1, color: cs.onSurfaceVariant, size: 20.sp),
                  SizedBox(width: 14.w),
                  Text(rows[i].$2,
                      style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                  SizedBox(width: 12.w),
                  // notes can run long, so the value wraps instead of clipping
                  Expanded(
                    child: Text(
                      rows[i].$3,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _userCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // tapping opens the public profile — reviews, role averages, badges
    return GestureDetector(
      onTap: post.user.id == 0
          ? null
          : () => Get.to(() =>
              UserReviewsPage(userId: post.user.id, userName: post.user.name)),
      child: Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22.r,
            backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
            child: Text(post.user.name[0],
                style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w700)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(post.user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                    ),
                    if (post.user.verified) ...[
                      SizedBox(width: 4.w),
                      Icon(Icons.verified, size: 15.sp, color: AppPalette.verified),
                    ],
                    if (post.user.isTransporter) ...[
                      SizedBox(width: 6.w),
                      TransporterChip(recommended: post.user.isRecommendedTransporter),
                    ],
                  ],
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Icon(Icons.star, size: 13.sp, color: Colors.amber),
                    SizedBox(width: 3.w),
                    Text(post.user.rating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          if (post.recommended)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppPalette.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text('recommended'.tr,
                  style: TextStyle(fontSize: 9.sp, color: AppPalette.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      ),
    );
  }
}
