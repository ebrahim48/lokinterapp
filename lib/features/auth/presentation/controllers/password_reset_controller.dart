import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/utils/notify.dart';
import '../../../../core/utils/validators.dart';
import '../../data/auth_repository.dart';

// Reset-password flow — one mechanism only, the emailed link:
//   1. POST /auth/forgotPassword { email } — the server emails a reset link
//   2. The user taps the link → the reset page opens with its token
//   3. New password + confirmation → password updated
//
// The app owns step 1 and then tells the user to check their inbox. It must
// not open the reset page itself: without the token from the email that page
// can't work, and asking for a "code" here mixed an OTP flow into a link flow.
class PasswordResetController extends GetxController {
  final email = TextEditingController();
  final busy = false.obs;
  /// Set once the email went out — the page switches to "check your inbox".
  final sentTo = RxnString();

  final _repo = AuthRepository();

  Future<void> sendLink() async {
    final addr = email.text.trim();
    if (!isValidEmail(addr)) {
      toast('enter_a_valid_email_address'.tr);
      return;
    }
    busy.value = true;
    try {
      final resend = sentTo.value != null;
      await _repo.forgotPassword(addr);
      sentTo.value = addr;
      if (resend) toast('reset_link_sent_again'.tr);
    } on AppException catch (e) {
      toastError(e);
    } finally {
      busy.value = false;
    }
  }

  /// Back to the email field, e.g. to fix a typo in the address.
  void editEmail() => sentTo.value = null;

  @override
  void onClose() {
    email.dispose();
    super.onClose();
  }
}
