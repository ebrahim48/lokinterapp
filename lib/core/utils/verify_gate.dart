import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/profile/data/kyc_repository.dart';
import '../../features/profile/presentation/basic_info_page.dart';
import '../exceptions/app_exceptions.dart';
import '../theme/app_palette.dart';
import 'notify.dart';

// Identity verification gates DEAL CREATION (the agreement), not chatting or
// posting — that's where the live app requires it. Returns true when the user
// is verified; otherwise shows the prompt and returns false.
Future<bool> requireVerified() async {
  KycStatus kyc;
  try {
    kyc = await KycRepository().status();
  } on AppException catch (e) {
    toastError(e);
    return false;
  }
  if (kyc.verified) return true;

  await Get.dialog<void>(
    AlertDialog(
      title: Text('verify_your_identity'.tr),
      content: Text(kyc.message),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('not_now'.tr)),
        TextButton(
          onPressed: () {
            Get.back();
            Get.to(() => const BasicInfoPage());
          },
          child: Text('verify'.tr, style: TextStyle(color: AppPalette.primary)),
        ),
      ],
    ),
  );
  return false;
}
