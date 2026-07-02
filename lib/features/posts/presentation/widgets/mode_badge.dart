import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_palette.dart';
import '../../data/models/post_model.dart';

// Local = green pin, International = blue plane. Used on cards and rails.
class ModeBadge extends StatelessWidget {
  final PostLocation location;
  final bool showLabel;
  final Color? labelColor;

  const ModeBadge({
    super.key,
    required this.location,
    this.showLabel = true,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final local = location == PostLocation.local;
    final color = local ? AppPalette.localAccent : AppPalette.intlAccent;
    final icon = local ? Icons.location_on : Icons.flight;

    final dot = Container(
      width: 34.r,
      height: 34.r,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 18.sp),
    );

    if (!showLabel) return dot;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        SizedBox(height: 4.h),
        Text(
          local ? 'LOCAL' : 'INTERNATIONAL',
          style: TextStyle(
            fontSize: 9.sp,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w600,
            color: labelColor ?? color,
          ),
        ),
      ],
    );
  }
}
