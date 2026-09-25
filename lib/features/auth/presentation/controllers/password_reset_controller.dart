import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/utils/notify.dart';
import '../../../../core/utils/validators.dart';
import '../../data/auth_repository.dart';
import '../login_page.dart';

// Reset-password flow (spec §10):
//   1. POST /auth/forgotPassword { email }
//   2. Open  {webBaseUrl}/reset-password?token=…&email=… in browser (WebView OK)
//   3. POST /auth/resetPassword  { token, email, password, passwordConfirmation }
//
// There is no reset-OTP API — the token travels via email link, not in-app.
// The old OTP screen is therefore removed; after step 1 we open the web page.
class PasswordResetController extends GetxController {
  final email = TextEditingController();
  // These are kept so the ResetPasswordPage (manual-token fallback) can still
  // work if the user copies their token from the email themselves.
  final token = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final busy = false.obs;

  final _repo = AuthRepository();

  // Step 1: send the email, then open the web reset page.
  Future<void> sendCode() async {
    final addr = email.text.trim();
    if (!isValidEmail(addr)) {
      toast('enter_a_valid_email_address'.tr);
      return;
    }
    busy.value = true;
    try {
      await _repo.forgotPassword(addr);

      // Open the web reset page — the email link and this URL land on the same
      // form; the user fills in their new password there.
      final uri = Uri.parse(
        '${ApiConstants.webBaseUrl}/reset-password'
        '?email=${Uri.encodeComponent(addr)}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } else {
        // Fallback: show the manual reset page in-app.
        toast('reset_code_sent_check_your_inbox'.tr);
        Get.to(() => _ResetPasswordFallbackPage(email: addr));
        return;
      }
      toast('reset_code_sent_check_your_inbox'.tr);
    } on AppException catch (e) {
      toastError(e);
    } finally {
      busy.value = false;
    }
  }

  // Step 3 (manual fallback path — user copies token from email).
  Future<void> reset() async {
    if (token.text.trim().isEmpty || password.text.isEmpty) {
      toast('enter_the_code_and_a_new_password'.tr);
      return;
    }
    if (!isValidPassword(password.text)) {
      toast('password_must_be_at_least_8_characters'.tr);
      return;
    }
    if (password.text != confirm.text) {
      toast('passwords_do_not_match'.tr);
      return;
    }
    busy.value = true;
    try {
      await _repo.resetPassword(
        email: email.text.trim(),
        token: token.text.trim(),
        password: password.text,
      );
      toast('password_updated_log_in_with_the_new_one'.tr);
      Get.offAll(() => const LoginPage());
    } on AppException catch (e) {
      toastError(e);
    } finally {
      busy.value = false;
    }
  }

  @override
  void onClose() {
    email.dispose();
    token.dispose();
    password.dispose();
    confirm.dispose();
    super.onClose();
  }
}

// Internal fallback — only shown when the system cannot open the URL.
// The user can paste the token from the email here.
class _ResetPasswordFallbackPage extends StatelessWidget {
  final String email;
  const _ResetPasswordFallbackPage({required this.email});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<PasswordResetController>()..email.text = email;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text('reset_password'.tr, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'enter_the_code_we_sent_and_choose_a_new_password'.tr,
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: c.token,
            decoration: InputDecoration(
              labelText: 'reset_code'.tr,
              hintText: 'code_from_the_email'.tr,
              prefixIcon: const Icon(Icons.pin_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: c.password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'new_password'.tr,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: c.confirm,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'confirm_password'.tr,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 20),
          Obx(
            () => ElevatedButton(
              onPressed: c.busy.value ? null : c.reset,
              child: c.busy.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('reset_password'.tr),
            ),
          ),
        ],
      ),
    );
  }
}
