import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/flags.dart';
import '../../../../core/utils/format.dart';
import '../../data/models/post_model.dart';
import 'corner_ribbon.dart';
import 'mode_badge.dart';
import 'transporter_chip.dart';

// Picks the right card for a post: coral for delivery requests, white for trips.
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onChat;
  final VoidCallback? onTap;
  final bool showChat; // hidden on the user's own posts
  final bool showUser; // also hidden on own posts — no point showing yourself

  const PostCard({
    super.key,
    required this.post,
    this.onChat,
    this.onTap,
    this.showChat = true,
    this.showUser = true,
  });

  @override
  Widget build(BuildContext context) {
    // no chatting with yourself — hide the pill on the user's own posts
    final myId = Get.find<SessionService>().user.value?.id;
    final chat = showChat && !(post.user.id != 0 && post.user.id == myId);

    return post.isTrip
        ? TripCard(post: post, onChat: onChat, onTap: onTap, showChat: chat, showUser: showUser)
        : RequestCard(post: post, onChat: onChat, onTap: onTap, showChat: chat, showUser: showUser);
  }
}

// Coral delivery-request card.
class RequestCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onChat;
  final VoidCallback? onTap;
  final bool showChat;
  final bool showUser;

  const RequestCard({
    super.key,
    required this.post,
    this.onChat,
    this.onTap,
    this.showChat = true,
    this.showUser = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 14.h),
        decoration: BoxDecoration(
          color: AppPalette.requestCard,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: AppPalette.requestCard.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.user.isTransporter) ...[
              const TransporterChip(),
              SizedBox(height: 10.h),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _typePill(),
                      SizedBox(height: 10.h),
                      Text(
                        post.title ?? '${post.from} → ${post.to}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 19.sp, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${post.from} → ${post.to}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13.sp),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                _image(),
              ],
            ),
            if (post.description != null) ...[
              SizedBox(height: 8.h),
              Text(
                post.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12.sp, height: 1.3),
              ),
            ],
            SizedBox(height: 14.h),
            Row(
              children: [
                _meta(Icons.card_giftcard, 'PROFIT', post.profit ?? '-'),
                _meta(Icons.shopping_bag_outlined, 'WEIGHT', kg(post.weight)),
                _meta(Icons.event_outlined, 'BEFORE', dayMonth(post.date)),
              ],
            ),
            if (showUser || showChat) ...[
              SizedBox(height: 12.h),
              const _DashedLine(),
              SizedBox(height: 12.h),
              Row(
                children: [
                  if (showUser) Expanded(child: _userName()) else const Spacer(),
                  if (showChat) _ChatPill(onTap: onChat, light: true),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // navy pill: mode indicator (local flag / intl plane) merged with the request type
  Widget _typePill() {
    final buy = post.wantTo == WantTo.buyAndDeliver;
    final local = post.isLocal;
    return Container(
      padding: EdgeInsets.fromLTRB(local ? 4.w : 10.w, 4.h, 12.w, 4.h),
      decoration: BoxDecoration(color: AppPalette.navy, borderRadius: BorderRadius.circular(24.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (local)
            CountryFlag.fromCountryCode(
              post.flagIso ?? countryCodeFor(post.from),
              height: 22.r,
              width: 22.r,
              shape: const Circle(),
            )
          else
            Icon(Icons.flight, color: AppPalette.intlAccent, size: 16.sp),
          SizedBox(width: 7.w),
          Flexible(
            child: Text(
              buy ? 'BUY FOR ME & DELIVER' : 'DELIVER READY ITEMS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _image() {
    final box = 84.r;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        width: box,
        height: box,
        color: Colors.white.withValues(alpha: 0.16),
        child: post.imageUrl != null
            ? Image.network(
                post.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.image_outlined,
                    color: Colors.white.withValues(alpha: 0.8), size: 30.sp),
              )
            : Icon(Icons.image_outlined, color: Colors.white.withValues(alpha: 0.8), size: 30.sp),
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
            style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w800),
          ),
        ),
        if (post.user.verified) ...[
          SizedBox(width: 4.w),
          Icon(Icons.verified, color: AppPalette.verified, size: 15.sp),
        ],
      ],
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
              Text(label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 9.sp,
                    letterSpacing: 0.5,
                  )),
            ],
          ),
          SizedBox(height: 3.h),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// White trip card.
class TripCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onChat;
  final VoidCallback? onTap;
  final bool showChat;
  final bool showUser;

  const TripCard({
    super.key,
    required this.post,
    this.onChat,
    this.onTap,
    this.showChat = true,
    this.showUser = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
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
                if (post.user.isTransporter) SizedBox(height: 24.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _endpoint('FROM', post.from, CrossAxisAlignment.start)),
                    ModeBadge(location: post.location, place: post.from, iso: post.flagIso),
                    Expanded(child: _endpoint('TO', post.to, CrossAxisAlignment.end)),
                  ],
                ),
                SizedBox(height: 14.h),
                Divider(color: AppPalette.navy.withValues(alpha: 0.1), height: 1),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    _meta(Icons.event_outlined, 'DATE', shortDate(post.date)),
                    _meta(Icons.luggage_outlined, 'WEIGHT', kg(post.remainingWeight ?? post.weight),
                        alignEnd: true),
                  ],
                ),
                if (showUser || showChat) ...[
                  SizedBox(height: 12.h),
                  Divider(color: AppPalette.navy.withValues(alpha: 0.1), height: 1),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      if (showUser)
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
                            ],
                          ),
                        )
                      else
                        const Spacer(),
                      if (showChat) _ChatPill(onTap: onChat, light: false),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (post.user.isTransporter)
            CornerRibbon(text: 'TRANSPORTER', color: AppPalette.primary, radius: 16.r),
        ],
      ),
    );
  }

  Widget _endpoint(String label, String value, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label,
            style: TextStyle(
              color: AppPalette.navy.withValues(alpha: 0.55),
              fontSize: 10.sp,
              letterSpacing: 0.5,
            )),
        SizedBox(height: 2.h),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppPalette.navy, fontSize: 18.sp, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _meta(IconData icon, String label, String value, {bool alignEnd = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                color: AppPalette.navy.withValues(alpha: 0.55),
                fontSize: 9.sp,
                letterSpacing: 0.5,
              )),
          SizedBox(height: 3.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13.sp, color: AppPalette.navy.withValues(alpha: 0.7)),
              SizedBox(width: 5.w),
              Text(value,
                  style: TextStyle(color: AppPalette.navy, fontSize: 12.sp, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatPill extends StatelessWidget {
  final VoidCallback? onTap;
  final bool light;

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
            Text('chat', style: TextStyle(color: Colors.white, fontSize: 12.sp)),
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
            (_) => Container(width: dash, height: 1, color: Colors.white.withValues(alpha: 0.34)),
          ),
        );
      },
    );
  }
}
