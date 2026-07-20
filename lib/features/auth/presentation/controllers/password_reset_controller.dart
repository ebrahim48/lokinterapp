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
      toast('Enter a valid email address');
      return;
    }
    busy.value = true;
    try {
      await _repo.forgotPassword(email.text.trim());
      toast('Reset code sent — check your inbox');
      Get.to(() => const ResetPasswordPage());
    } on AppException catch (e) {
      toastError(e);
    } finally {
      busy.value = false;
    }
  }

  Future<void> reset() async {
    if (token.text.trim().isEmpty || password.text.isEmpty) {
      toast('Enter the code and a new password');
      return;
    }
    if (!isValidPassword(password.text)) {
      toast('Password must be at least 8 characters');
      return;
    }
    if (password.text != confirm.text) {
      toast('Passwords do not match');
      return;
    }
    busy.value = true;
    try {
      await _repo.resetPassword(
        email: email.text.trim(),
        token: token.text.trim(),
        password: password.text,
      );
      toast('Password updated — log in with the new one');
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
