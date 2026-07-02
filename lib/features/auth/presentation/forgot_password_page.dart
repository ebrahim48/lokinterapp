import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/widgets/lok_fields.dart';
import 'reset_password_page.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
        children: [
          Text('Forgot password', style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: 6.h),
          Text(
            "Enter your email and we'll send you a reset code.",
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
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: () => Get.to(() => const ResetPasswordPage()),
            child: const Text('Send reset code'),
          ),
        ],
      ),
    );
  }
}
