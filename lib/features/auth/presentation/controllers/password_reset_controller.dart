import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/utils/notify.dart';
import '../../../../core/utils/validators.dart';
import '../../data/auth_repository.dart';
import '../login_page.dart';
import '../reset_password_page.dart';

// Handles both halves of the flow: request the emailed code, then reset.
class PasswordResetController extends GetxController {
  final email = TextEditingController();
  final token = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final busy = false.obs;

  final _repo = AuthRepository();

  Future<void> sendCode() async {
    if (!isValidEmail(email.text)) {
      toast('enter_a_valid_email_address'.tr);
      return;
    }
    busy.value = true;
    try {
      await _repo.forgotPassword(email.text.trim());
      toast('reset_code_sent_check_your_inbox'.tr);
      Get.to(() => const ResetPasswordPage());
    } on AppException catch (e) {
      toastError(e);
    } finally {
      busy.value = false;
    }
  }

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
