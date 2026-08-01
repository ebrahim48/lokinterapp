import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/format.dart';
import '../../../posts/data/models/post_model.dart';
import '../../../posts/presentation/widgets/mode_badge.dart';
import '../../../posts/presentation/widgets/transporter_chip.dart';

// Horizontal rail of recommended travelers shown under the banner.
class RecommendedRail extends StatelessWidget {
  final List<Post> travelers;
  final void Function(Post)? onTap;
  const RecommendedRail({super.key, required this.travelers, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 144.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        itemCount: travelers.length,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (_, i) => _TravelerCard(
          post: travelers[i],
          onTap: onTap == null ? null : () => onTap!(travelers[i]),
        ),
      ),
    );
  }
}

class _TravelerCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  const _TravelerCard({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: 198.w,
      padding: EdgeInsets.all(11.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (post.user.isTransporter) ...[
            TransporterChip(recommended: post.user.isRecommendedTransporter),
            SizedBox(height: 6.h),
          ],
          Row(
            children: [
              CircleAvatar(
                radius: 13.r,
                backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
                child: Text(
                  post.user.name[0],
                  style: TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w700, fontSize: 12.sp),
                ),
              ),
              SizedBox(width: 7.w),
              Expanded(
                child: Text(
                  post.user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5.sp, color: cs.onSurface),
                ),
              ),
              ModeBadge(location: post.location, place: post.from, iso: post.flagIso, showLabel: false),
            ],
          ),
          SizedBox(height: 7.h),
          Text(
            '${post.from} → ${post.to}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5.sp, color: cs.onSurface),
          ),
          SizedBox(height: 2.h),
          Text(post.dateText, style: TextStyle(fontSize: 10.5.sp, color: cs.onSurfaceVariant)),
          SizedBox(height: 6.h),
          Text(
            '${kg(post.remainingWeight ?? post.weight)} space left',
            style: TextStyle(fontSize: 10.5.sp, color: cs.onSurfaceVariant),
          ),
        ],
      ),
      ),
    );
  }
}
