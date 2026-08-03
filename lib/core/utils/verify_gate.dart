import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/profile/data/kyc_repository.dart';
import '../../features/profile/presentation/basic_info_page.dart';
import '../exceptions/app_exceptions.dart';
import '../theme/app_palette.dart';
import 'notify.dart';

// Identity verification gates the AGREEMENT — the sender's "confirm agreement
// and continue" and the traveler's "accept deal". Posting and chatting only
// need a verified phone number (see requirePhoneVerified).
//
// Returns true when the user is verified; otherwise shows the prompt and
// returns false.
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

/// Handles the API's `403 { requiresKyc: true }` for callers that reached the
/// server anyway — a stale session, or verification revoked mid-flow. Returns
/// true when it showed the verification prompt, so the caller can skip its
/// usual error toast.
bool maybeKycPrompt(AppException e) {
  // `details` is a plain string, so match on what the API actually says
  final probe = '${e.message} ${e.details ?? ''}'.toLowerCase();
  if (!probe.contains('requireskyc') &&
      !probe.contains('document verification is required')) {
    return false;
  }

  Get.dialog<void>(
    AlertDialog(
      title: Text('verify_your_identity'.tr),
      content: Text(e.message),
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
  return true;
}
