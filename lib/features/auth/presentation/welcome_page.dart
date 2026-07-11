import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../core/widgets/lokinter_logo.dart';
import '../../shell/presentation/main_shell.dart';
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 28.h),
          child: Column(
            children: [
              Align(alignment: Alignment.centerRight, child: const LanguageSelector()),
              const Spacer(),
              const LokinterLogo(fontSize: 40),
              SizedBox(height: 20.h),
              _hero(),
              SizedBox(height: 24.h),
              Text(
                'Ship anything, anywhere',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: 8.h),
              Text(
                'Connect with travelers heading your way and send '
                'parcels locally or across the world.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.5),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Get.to(() => const LoginPage()),
                child: const Text('Login'),
              ),
              SizedBox(height: 12.h),
              OutlinedButton(
                onPressed: () => Get.to(() => const RegisterPage()),
                child: const Text('Create an account'),
              ),
              SizedBox(height: 12.h),
              TextButton(
                onPressed: () => Get.offAll(() => const MainShell()),
                child: Text(
                  'Continue as guest',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.sp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return SizedBox(
      width: 240.r,
      height: 240.r,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 210.r,
            height: 210.r,
            child: const _HeroCarousel(),
          ),
          _floating(Alignment.topLeft, Icons.flight, AppPalette.intlAccent),
          _floating(Alignment.topRight, Icons.people_alt_outlined, AppPalette.primary),
          _floating(Alignment.bottomLeft, Icons.inventory_2_outlined, AppPalette.primary),
          _floating(Alignment.bottomRight, Icons.verified_user_outlined, AppPalette.intlAccent),
        ],
      ),
    );
  }

  Widget _floating(Alignment align, IconData icon, Color color) {
    return Align(
      alignment: align,
      child: Container(
        padding: EdgeInsets.all(10.r),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Icon(icon, color: color, size: 20.sp),
      ),
    );
  }
}

// Client wants the hero to rotate through a few animations rather than sit on one.
// Timer-driven so a missing asset (shows its fallback icon) never stalls the loop.
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel();

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  static const _clips = [
    ('assets/animations/traveling_girl.json', Icons.public),
    ('assets/animations/loading_car.json', Icons.local_shipping_outlined),
    ('assets/animations/shopping_cart.json', Icons.shopping_cart_outlined),
  ];

  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _i = (_i + 1) % _clips.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (path, fallback) = _clips[_i];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: Lottie.asset(
        path,
        key: ValueKey(path),
        width: 210.r,
        height: 210.r,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(fallback, color: AppPalette.primary, size: 90.sp),
      ),
    );
  }
}
