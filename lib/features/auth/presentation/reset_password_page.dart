import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/widgets/lok_busy_button.dart';
import '../../../core/widgets/lok_fields.dart';
import 'controllers/password_reset_controller.dart';

class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<PasswordResetController>();
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
          LokTextField(
            label: 'Reset code',
            hint: 'code from the email',
            icon: Icons.pin_outlined,
            required: true,
            controller: c.token,
          ),
          SizedBox(height: 16.h),
          LokPasswordField(label: 'New password', hint: 'new password', controller: c.password),
          SizedBox(height: 16.h),
          LokPasswordField(label: 'Confirm password', hint: 'repeat password', controller: c.confirm),
          SizedBox(height: 20.h),
          LokBusyButton(busy: c.busy, label: 'Reset password', onPressed: c.reset),
        ],
      ),
    );
  }
}
