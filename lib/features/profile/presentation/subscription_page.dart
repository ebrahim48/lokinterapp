import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_palette.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  static const _features = [
    'Post unlimited trips',
    'Priority placement in search',
    'Lower service fees on deals',
    'Verified traveler badge',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              gradient: const LinearGradient(
                colors: [AppPalette.deepNavy, AppPalette.navy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lokinter Plus',
                    style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w800)),
                SizedBox(height: 6.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('USD 9.99',
                        style: TextStyle(color: Colors.white, fontSize: 26.sp, fontWeight: FontWeight.w800)),
                    Padding(
                      padding: EdgeInsets.only(bottom: 4.h, left: 4.w),
                      child: Text('/month',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.sp)),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                for (final f in _features)
                  Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppPalette.verified, size: 18.sp),
                        SizedBox(width: 10.w),
                        Text(f, style: TextStyle(color: Colors.white, fontSize: 13.sp)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          ElevatedButton(onPressed: () {}, child: const Text('Subscribe')),
          SizedBox(height: 12.h),
          Text(
            'You can cancel anytime. Your plan renews automatically each month.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
