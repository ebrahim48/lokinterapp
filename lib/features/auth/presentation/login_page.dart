import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../shell/presentation/main_shell.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
        children: [
          Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: 6.h),
          Text(
            'Log in to keep shipping and traveling.',
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
          ),
          SizedBox(height: 28.h),
          const LokTextField(
            label: 'Email',
            hint: 'you@email.com',
            icon: Icons.mail_outline,
            required: true,
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 16.h),
          const LokPasswordField(),
          SizedBox(height: 8.h),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Get.to(() => const ForgotPasswordPage()),
              child: Text(
                'Forgot password?',
                style: TextStyle(color: AppPalette.primary, fontSize: 12.sp),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          ElevatedButton(
            onPressed: () => Get.offAll(() => const MainShell()),
            child: const Text('Login'),
          ),
          SizedBox(height: 18.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
              ),
              GestureDetector(
                onTap: () => Get.off(() => const RegisterPage()),
                child: Text(
                  'Register',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
