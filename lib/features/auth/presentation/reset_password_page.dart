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
          Text('reset_password'.tr, style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: 6.h),
          Text(
            'enter_the_code_we_sent_and_choose_a_new_password'.tr,
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
          ),
          SizedBox(height: 28.h),
          LokTextField(
            label: 'reset_code'.tr,
            hint: 'code_from_the_email'.tr,
            icon: Icons.pin_outlined,
            required: true,
            controller: c.token,
          ),
          SizedBox(height: 16.h),
          LokPasswordField(label: 'new_password'.tr, hint: 'new_password_2'.tr, controller: c.password),
          SizedBox(height: 16.h),
          LokPasswordField(label: 'confirm_password'.tr, hint: 'repeat_password'.tr, controller: c.confirm),
          SizedBox(height: 20.h),
          LokBusyButton(busy: c.busy, label: 'reset_password'.tr, onPressed: c.reset),
        ],
      ),
    );
  }
}
