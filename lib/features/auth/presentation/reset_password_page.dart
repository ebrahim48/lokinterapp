import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/widgets/lok_fields.dart';
import 'login_page.dart';

class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
        children: [
          Text('Reset password', style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: 6.h),
          Text(
            'Enter the code we sent and choose a new password.',
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
          ),
          SizedBox(height: 28.h),
          const LokTextField(
            label: 'Reset code',
            hint: '6-digit code',
            icon: Icons.pin_outlined,
            required: true,
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 16.h),
          const LokPasswordField(label: 'New password', hint: 'new password'),
          SizedBox(height: 16.h),
          const LokPasswordField(label: 'Confirm password', hint: 'repeat password'),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: () => Get.offAll(() => const LoginPage()),
            child: const Text('Reset password'),
          ),
        ],
      ),
    );
  }
}
