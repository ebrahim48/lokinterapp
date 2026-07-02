import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_palette.dart';

// Top image banner. Placeholder gradients until real banner images come from the API.
class HomeBanner extends StatefulWidget {
  const HomeBanner({super.key});

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> {
  final _pageController = PageController();
  int _index = 0;

  static const _slides = [
    ('Ship anywhere', 'Send parcels with trusted travelers', [AppPalette.deepNavy, AppPalette.navy]),
    ('Travel & earn', 'Carry items on trips you already take', [Color(0xFF7A3B38), AppPalette.primary]),
    ('Local or worldwide', 'Inside your city or across borders', [Color(0xFF1E4D3A), AppPalette.localAccent]),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 140.h,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final s = _slides[i];
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18.r),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: s.$3,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      s.$1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      s.$2,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 3.w),
              width: active ? 18.w : 7.w,
              height: 7.h,
              decoration: BoxDecoration(
                color: active ? AppPalette.primary : AppPalette.grey,
                borderRadius: BorderRadius.circular(4.r),
              ),
            );
          }),
        ),
      ],
    );
  }
}
