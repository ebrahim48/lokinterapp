import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_palette.dart';

// Big tappable choice card — Local/International, Buy/Deliver, etc.
class OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const OptionCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected ? AppPalette.primary : cs.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 46.r,
                  height: 46.r,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24.sp),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? AppPalette.primary : cs.outline,
                  size: 20.sp,
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
