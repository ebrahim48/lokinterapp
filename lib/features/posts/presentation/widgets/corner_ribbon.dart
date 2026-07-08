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
              Positioned(
                top: 14.h,
                left: -34.w,
                child: Transform.rotate(
                  angle: -math.pi / 4,
                  child: Container(
                    width: 140.w,
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    color: color,
                    alignment: Alignment.center,
                    child: Text(
                      text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
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
