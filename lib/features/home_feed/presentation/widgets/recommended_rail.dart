import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/format.dart';
import '../../../posts/data/models/post_model.dart';
import '../../../posts/presentation/widgets/mode_badge.dart';
import '../../../posts/presentation/widgets/transporter_badge.dart';

// Horizontal rail of recommended travelers shown under the banner.
class RecommendedRail extends StatelessWidget {
  final List<Post> travelers;
  const RecommendedRail({super.key, required this.travelers});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132.h,
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
    return Container(
      width: 230.w,
      padding: EdgeInsets.all(14.w),
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
                radius: 16.r,
                backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
                child: Text(
                  post.user.name[0],
                  style: TextStyle(
                    color: AppPalette.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
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
              if (post.user.isTransporter) ...[
                const TransporterBadge(compact: true),
                SizedBox(width: 6.w),
              ],
              ModeBadge(location: post.location, showLabel: false),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            '${post.from} → ${post.to}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14.sp,
              color: cs.onSurface,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            shortDate(post.date),
            style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${kg(post.remainingWeight ?? post.weight)} space left',
                style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'Recommended',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
