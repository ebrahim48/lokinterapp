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
      body: Obx(() {
        final sentTo = c.sentTo.value;
        if (sentTo != null) return _sent(context, c, sentTo);
        return ListView(
          padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
          children: [
            Text('forgot_password'.tr, style: Theme.of(context).textTheme.headlineMedium),
            SizedBox(height: 6.h),
            Text(
              'enter_your_email_and_well_send_you_a_reset_link'.tr,
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
            LokBusyButton(busy: c.busy, label: 'send_reset_link'.tr, onPressed: c.sendLink),
          ],
        );
      }),
    );
  }

  // After sending: the link in the email is the only way forward.
  Widget _sent(BuildContext context, PasswordResetController c, String email) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
      children: [
        Icon(Icons.mark_email_read_outlined, size: 56.sp, color: cs.primary),
        SizedBox(height: 16.h),
        Text('check_your_email'.tr, style: Theme.of(context).textTheme.headlineMedium),
        SizedBox(height: 8.h),
        Text(
          'reset_link_sent_to'.trParams({'email': email}),
          style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.45),
        ),
        SizedBox(height: 28.h),
        ElevatedButton(onPressed: () => Get.back(), child: Text('back_to_login'.tr)),
        SizedBox(height: 12.h),
        Obx(() => OutlinedButton(
              onPressed: c.busy.value ? null : c.sendLink,
              child: Text('resend_reset_link'.tr),
            )),
        SizedBox(height: 4.h),
        TextButton(onPressed: c.editEmail, child: Text('use_a_different_email'.tr)),
      ],
    );
  }
}
