import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/lok_busy_button.dart';
import '../../../core/widgets/lok_fields.dart';
import 'controllers/register_controller.dart';

// Second register step — the code from the verification email.
class OtpPage extends StatefulWidget {
  const OtpPage({super.key});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<RegisterController>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
        children: [
          Text('verify_your_email'.tr, style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: 6.h),
          Text(
            'We sent a code to ${c.email.text.trim()}. Enter it below to finish creating your account.',
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.4),
          ),
          SizedBox(height: 28.h),
          LokTextField(
            label: 'verification_code'.tr,
            hint: 'code_from_the_email'.tr,
            icon: Icons.pin_outlined,
            required: true,
            keyboardType: TextInputType.number,
            controller: _code,
          ),
          SizedBox(height: 20.h),
          LokBusyButton(
            busy: c.busy,
            label: 'verify_create_account'.tr,
            onPressed: () => c.verifyOtp(_code.text.trim()),
          ),
          SizedBox(height: 16.h),
          Center(
            child: TextButton(
              onPressed: () => c.resendOtp(),
              child: Text(
                'resend_code'.tr,
                style: TextStyle(color: AppPalette.primary, fontSize: 13.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
