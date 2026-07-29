import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/utils/notify.dart';
import '../../../../core/utils/validators.dart';
import '../../../shell/presentation/main_shell.dart';
import '../../data/auth_repository.dart';

class LoginController extends GetxController {
  final email = TextEditingController();
  final password = TextEditingController();
  final busy = false.obs;

  final _repo = AuthRepository();

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      toast('enter_your_email_and_password'.tr);
      return;
    }
    if (!isValidEmail(email.text)) {
      toast('that_email_address_does_not_look_right'.tr);
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
