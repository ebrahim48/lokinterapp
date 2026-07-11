import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Diagonal corner banner (e.g. "TRANSPORTER"), clipped to the card's rounded corner.
class CornerRibbon extends StatelessWidget {
  final String text;
  final Color color;
  final double radius; // card corner radius, so the ribbon clips cleanly

  const CornerRibbon({
    super.key,
    required this.text,
    required this.color,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: [
              // Centered on the corner's diagonal so the whole word stays inside
              // the clipped triangle — off-center offsets clip the end letters.
              Positioned(
                top: 16.h,
                left: -42.w,
                child: Transform.rotate(
                  angle: -math.pi / 4,
                  child: Container(
                    width: 130.w,
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    color: color,
                    alignment: Alignment.center,
                    child: Text(
                      text,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
