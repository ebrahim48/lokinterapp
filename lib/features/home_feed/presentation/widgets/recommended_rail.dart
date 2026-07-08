import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/format.dart';
import '../../../posts/data/models/post_model.dart';
import '../../../posts/presentation/widgets/corner_ribbon.dart';
import '../../../posts/presentation/widgets/mode_badge.dart';

// Horizontal rail of recommended travelers shown under the banner.
class RecommendedRail extends StatelessWidget {
  final List<Post> travelers;
  const RecommendedRail({super.key, required this.travelers});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        itemCount: travelers.length,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (_, i) => _TravelerCard(post: travelers[i]),
      ),
    );
  }
}

class _TravelerCard extends StatelessWidget {
  final Post post;
  const _TravelerCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          width: 220.w,
          padding: EdgeInsets.all(13.w),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 15.r,
                    backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
                    child: Text(
                      post.user.name[0],
                      style: TextStyle(
                        color: AppPalette.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      post.user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  ModeBadge(location: post.location, place: post.from, showLabel: false),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                '${post.from} → ${post.to}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp, color: cs.onSurface),
              ),
              SizedBox(height: 4.h),
              Text(
                shortDate(post.date),
                style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                '${kg(post.remainingWeight ?? post.weight)} space left',
                style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (post.user.isTransporter)
          CornerRibbon(text: 'TRANSPORTER', color: AppPalette.primary, radius: 16.r),
      ],
    );
  }
}
