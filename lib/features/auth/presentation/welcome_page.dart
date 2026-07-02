import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
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
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 28.h),
          child: Column(
            children: [
              const Spacer(),
              Text(
                'LOKINTER',
                style: TextStyle(
                  color: AppPalette.primary,
                  fontSize: 34.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 14.h),
              Container(
                width: 180.r,
                height: 180.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppPalette.deepNavy, AppPalette.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(Icons.public, color: Colors.white, size: 90.sp),
              ),
              SizedBox(height: 28.h),
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
              SizedBox(height: 14.h),
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
}
