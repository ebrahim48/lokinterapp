import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../data/deal_model.dart';

class StatusBadge extends StatelessWidget {
  final DealStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = status.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: fg, fontSize: 10.sp, fontWeight: FontWeight.w700),
      ),
    );
  }
}
