import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_palette.dart';

// Marks a registered transporter. `onColor` for use on the coral/navy cards,
// `compact` shows just the truck icon (tight footers).
class TransporterBadge extends StatelessWidget {
  final bool onColor;
  final bool compact;

  const TransporterBadge({super.key, this.onColor = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final fg = onColor ? Colors.white : AppPalette.primary;
    final bg = onColor
        ? Colors.white.withValues(alpha: 0.18)
        : AppPalette.primary.withValues(alpha: 0.14);

    if (compact) {
      return Container(
        padding: EdgeInsets.all(4.r),
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(Icons.local_shipping, size: 12.sp, color: fg),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping, size: 11.sp, color: fg),
          SizedBox(width: 4.w),
          Text(
            'Transporter',
            style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}
