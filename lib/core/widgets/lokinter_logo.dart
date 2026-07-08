import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_palette.dart';

// Lokinter wordmark — coral "Lok" with a parcel mark, navy "inter".
// Swap for the official logo asset when available.
class LokinterLogo extends StatelessWidget {
  final double fontSize;
  const LokinterLogo({super.key, this.fontSize = 24});

  @override
  Widget build(BuildContext context) {
    final coral = GoogleFonts.bricolageGrotesque(
      fontSize: fontSize.sp,
      fontWeight: FontWeight.w800,
      color: AppPalette.primary,
      letterSpacing: -0.5,
    );
    final navy = coral.copyWith(color: AppPalette.navy);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('L', style: coral),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 1.w),
          child: Icon(Icons.inventory_2, color: AppPalette.primary, size: (fontSize * 0.82).sp),
        ),
        Text('kinter', style: navy),
      ],
    );
  }
}
