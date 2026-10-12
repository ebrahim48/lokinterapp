import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_palette.dart';
import 'package:get/get.dart';

// Small solid pill marking a transporter — sits above card content so it never
// hides any info. A paid, in-date subscription shows the gold "recommended"
// variant; an approved transporter without one gets the plain badge.
class TransporterChip extends StatelessWidget {
  final bool recommended;
  const TransporterChip({super.key, this.recommended = false});

  // green pill with a diamond, matching the web profile
  static const _green = Color(0xFF1FB25A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: recommended ? _green : AppPalette.primary,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(recommended ? Icons.diamond_outlined : Icons.verified_user,
              color: Colors.white, size: 12.sp),
          SizedBox(width: 5.w),
          Text(
            recommended ? 'recommended_transporter_2'.tr : 'transporter'.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
