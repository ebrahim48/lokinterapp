import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/utils/notify.dart';
import '../../../shell/presentation/main_shell.dart';
import '../../data/auth_repository.dart';

class LoginController extends GetxController {
  final email = TextEditingController();
  final password = TextEditingController();
  final busy = false.obs;

  final _repo = AuthRepository();

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      toast('Enter your email and password');
      return;
    }
    busy.value = true;
    try {
      await _repo.login(email.text.trim(), password.text);
      Get.offAll(() => const MainShell());
    } on AppException catch (e) {
      toastError(e);
    } finally {
      busy.value = false;
    }
  }

  @override
  void onClose() {
    email.dispose();
    password.dispose();
    super.onClose();
  }
}
