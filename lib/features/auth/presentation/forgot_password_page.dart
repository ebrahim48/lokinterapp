import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/widgets/lok_busy_button.dart';
import '../../../core/widgets/lok_fields.dart';
import 'controllers/password_reset_controller.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PasswordResetController());
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
        children: [
          Text('forgot_password'.tr, style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: 6.h),
          Text(
            "Enter your email and we'll send you a reset code.",
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
          ),
          SizedBox(height: 28.h),
          LokTextField(
            label: 'email'.tr,
            hint: 'you_email_com'.tr,
            icon: Icons.mail_outline,
            required: true,
            keyboardType: TextInputType.emailAddress,
            controller: c.email,
          ),
          SizedBox(height: 20.h),
          LokBusyButton(busy: c.busy, label: 'send_reset_code'.tr, onPressed: c.sendCode),
        ],
      ),
    );
  }
}
