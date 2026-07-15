import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/auth_gate.dart';
import '../../../core/utils/format.dart';
import '../../chat/presentation/chat_conversation_page.dart';
import '../data/models/post_model.dart';
import 'widgets/mode_badge.dart';
import 'widgets/transporter_chip.dart';

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
          if (!post.isTrip)
            Container(
              height: 180.h,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: cs.outline),
              ),
              child: Icon(Icons.image_outlined, size: 56.sp, color: cs.onSurfaceVariant),
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
          // no chat button on the user's own posts
          if (post.user.id == 0 ||
              post.user.id != Get.find<SessionService>().user.value?.id)
            ElevatedButton.icon(
              onPressed: () {
                if (!requireLogin()) return;
                Get.to(() => ChatConversationPage(user: post.user, postId: post.id));
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text('Chat with ${post.user.name}'),
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
      (Icons.event_outlined, post.isTrip ? 'Trip date' : 'Before', shortDate(post.date)),
      (Icons.luggage_outlined, 'Weight', kg(post.remainingWeight ?? post.weight)),
      if (!post.isTrip) (Icons.category_outlined, 'Category', 'Electronics'),
      if (!post.isTrip && post.profit != null)
        (Icons.payments_outlined, 'Traveler profit', post.profit!),
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
            ListTile(
              leading: Icon(rows[i].$1, color: cs.onSurfaceVariant, size: 20.sp),
              title: Text(rows[i].$2, style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
              trailing: Text(rows[i].$3,
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _userCard(BuildContext context) {
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
                      const TransporterChip(),
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
              child: Text('Recommended',
                  style: TextStyle(fontSize: 9.sp, color: AppPalette.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
