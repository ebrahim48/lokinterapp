import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/format.dart';
import '../../data/models/post_model.dart';
import 'mode_badge.dart';
import 'transporter_badge.dart';

// Picks the right card for a post: coral for delivery requests, white for trips.
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onChat;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onChat, this.onTap});

  @override
  Widget build(BuildContext context) {
    return post.isTrip
        ? TripCard(post: post, onChat: onChat, onTap: onTap)
        : RequestCard(post: post, onChat: onChat, onTap: onTap);
  }
}

// Coral delivery-request card (home2 feed style).
class RequestCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onChat;
  final VoidCallback? onTap;

  const RequestCard({super.key, required this.post, this.onChat, this.onTap});

  @override
  Widget build(BuildContext context) {
    final buy = post.wantTo == WantTo.buyAndDeliver;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 14.h),
        decoration: BoxDecoration(
          color: AppPalette.requestCard,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: AppPalette.requestCard.withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _eyebrow(
                    buy ? Icons.shopping_bag_outlined : Icons.inventory_2_outlined,
                    buy ? 'BUY FOR ME AND DELIVER' : 'DELIVER PERSONAL ITEM',
                  ),
                ),
                _thumb(),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              post.title ?? '${post.from} → ${post.to}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              '${post.from} → ${post.to}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                _meta(Icons.card_giftcard, 'PROFIT', post.profit ?? '-'),
                _meta(Icons.shopping_bag_outlined, 'WEIGHT', kg(post.weight)),
                _meta(Icons.event_outlined, 'BEFORE', dayMonth(post.date)),
              ],
            ),
            SizedBox(height: 12.h),
            const _DashedLine(),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(child: _userName()),
                ModeBadge(
                  location: post.location,
                  showLabel: false,
                  labelColor: Colors.white,
                ),
                SizedBox(width: 10.w),
                _ChatPill(onTap: onChat, light: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _userName() {
    return Row(
      children: [
        Flexible(
          child: Text(
            post.user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (post.user.verified) ...[
          SizedBox(width: 4.w),
          Icon(Icons.verified, color: AppPalette.verified, size: 15.sp),
        ],
        if (post.user.isTransporter) ...[
          SizedBox(width: 6.w),
          const TransporterBadge(onColor: true, compact: true),
        ],
      ],
    );
  }

  Widget _eyebrow(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 15.sp),
        SizedBox(width: 6.w),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 10.sp,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumb() {
    return Container(
      width: 64.w,
      height: 52.h,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        color: Colors.white.withValues(alpha: 0.8),
        size: 22.sp,
      ),
    );
  }

  Widget _meta(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12.sp, color: Colors.white.withValues(alpha: 0.8)),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 9.sp,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// White trip card (the "trip result" look).
class TripCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onChat;
  final VoidCallback? onTap;

  const TripCard({super.key, required this.post, this.onChat, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _endpoint('FROM', post.from, CrossAxisAlignment.start)),
                ModeBadge(location: post.location),
                Expanded(child: _endpoint('TO', post.to, CrossAxisAlignment.end)),
              ],
            ),
            SizedBox(height: 14.h),
            Divider(color: AppPalette.navy.withValues(alpha: 0.1), height: 1),
            SizedBox(height: 12.h),
            Row(
              children: [
                _meta(Icons.event_outlined, 'DATE', shortDate(post.date)),
                _meta(
                  Icons.luggage_outlined,
                  'WEIGHT',
                  kg(post.remainingWeight ?? post.weight),
                  alignEnd: true,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Divider(color: AppPalette.navy.withValues(alpha: 0.1), height: 1),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppPalette.navy,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (post.user.verified) ...[
                        SizedBox(width: 4.w),
                        Icon(Icons.verified, color: AppPalette.verified, size: 15.sp),
                      ],
                      if (post.user.isTransporter) ...[
                        SizedBox(width: 6.w),
                        const TransporterBadge(compact: true),
                      ],
                    ],
                  ),
                ),
                _ChatPill(onTap: onChat, light: false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _endpoint(String label, String value, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppPalette.navy.withValues(alpha: 0.55),
            fontSize: 10.sp,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppPalette.navy,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _meta(IconData icon, String label, String value, {bool alignEnd = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppPalette.navy.withValues(alpha: 0.55),
              fontSize: 9.sp,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 3.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13.sp, color: AppPalette.navy.withValues(alpha: 0.7)),
              SizedBox(width: 5.w),
              Text(
                value,
                style: TextStyle(
                  color: AppPalette.navy,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatPill extends StatelessWidget {
  final VoidCallback? onTap;
  final bool light; // light = translucent-on-color, else coral pill

  const _ChatPill({this.onTap, required this.light});

  @override
  Widget build(BuildContext context) {
    final bg = light ? Colors.white.withValues(alpha: 0.1) : AppPalette.primary;
    final border = light ? Colors.white.withValues(alpha: 0.7) : AppPalette.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble, color: Colors.white, size: 13.sp),
            SizedBox(width: 6.w),
            Text(
              'chat',
              style: TextStyle(color: Colors.white, fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const dash = 5.0;
        final count = (c.maxWidth / (dash * 2)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dash,
              height: 1,
              color: Colors.white.withValues(alpha: 0.34),
            ),
          ),
        );
      },
    );
  }
}
