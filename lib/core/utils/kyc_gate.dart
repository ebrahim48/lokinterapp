import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/profile/data/kyc_repository.dart';
import '../../features/profile/presentation/basic_info_page.dart';
import '../exceptions/app_exceptions.dart';
import '../theme/app_palette.dart';
import 'auth_gate.dart';
import 'notify.dart';

/// Website parity: posting a trip or a delivery request requires a
/// verified identity (`identityVerificationGuard` on the web routes).
/// Returns true when the user may continue; otherwise shows the same
/// verify-first dialog the chat gate uses and returns false.
Future<bool> requireIdentityVerified({String action = 'post'}) async {
  if (!requireLogin()) return false;

  KycStatus kyc;
  try {
    kyc = await KycRepository().status();
  } on AppException catch (e) {
    toastError(e);
    return false;
  }

  if (kyc.verified) return true;

  Get.dialog(
    AlertDialog(
      title: const Text('Verify your identity'),
      content: Text(
        'You need a verified identity before you can $action. ${kyc.message}',
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Not now')),
        TextButton(
          onPressed: () {
            Get.back();
            Get.to(() => const BasicInfoPage());
          },
          child: const Text('Verify', style: TextStyle(color: AppPalette.primary)),
        ),
      ],
    ),
  );
  return false;
}
