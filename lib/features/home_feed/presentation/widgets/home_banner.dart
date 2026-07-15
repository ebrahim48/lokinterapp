import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../lookups/data/lookup_models.dart';

// Top banner — auto-advances between slides. Shows the admin-managed banners
// from the API; the gradient slides fill in while there's nothing to show.
class BannerCarousel extends StatefulWidget {
  final List<HomeBanner> banners;
  const BannerCarousel({super.key, this.banners = const []});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _pageController = PageController();
  Timer? _timer;
  int _index = 0;

  static const _slides = [
    ('Ship anywhere', 'Send parcels with trusted travelers', [AppPalette.deepNavy, AppPalette.navy]),
    ('Travel & earn', 'Carry items on trips you already take', [Color(0xFF7A3B38), AppPalette.primary]),
    ('Local or worldwide', 'Inside your city or across borders', [Color(0xFF1E4D3A), AppPalette.localAccent]),
  ];

  int get _count => widget.banners.isEmpty ? _slides.length : widget.banners.length;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pageController.hasClients || _count < 2) return;
      final next = (_index + 1) % _count;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 124.h,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _count,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) =>
                widget.banners.isEmpty ? _gradientSlide(i) : _imageSlide(widget.banners[i]),
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_count, (i) {
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

  Widget _imageSlide(HomeBanner banner) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: banner.imageUrl == null
            ? _gradientSlide(0)
            : CachedNetworkImage(
                imageUrl: banner.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppPalette.navy.withValues(alpha: 0.1)),
                errorWidget: (_, __, ___) => _gradientSlide(0),
              ),
      ),
    );
  }

  Widget _gradientSlide(int i) {
    final s = _slides[i % _slides.length];
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
            style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6.h),
          Text(
            s.$2,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}
