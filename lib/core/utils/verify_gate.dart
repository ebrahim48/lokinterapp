import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/profile/data/kyc_repository.dart';
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

  final go = await Get.dialog<bool>(
    AlertDialog(
      title: Text('verify_your_identity'.tr),
      content: Text(kyc.message),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false), child: Text('not_now'.tr)),
        TextButton(
          onPressed: () => Get.back(result: true),
          child: Text('verify'.tr, style: TextStyle(color: AppPalette.primary)),
        ),
      ],
    ),
  );
  if (go == true) await startKycVerification();
  return false;
}

/// Opens the provider's hosted document check (`POST /kyc/verify` →
/// `verificationUrl`). The result arrives by webhook, so the caller can't
/// continue in this pass — the user comes back once the check clears.
Future<void> startKycVerification() async {
  try {
    final url = await KycRepository().startVerification();
    if (url == null || url.isEmpty) {
      toast('could_not_open_the_verification_page'.tr);
      return;
    }
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) toast('could_not_open_the_verification_page'.tr);
  } on AppException catch (e) {
    toastError(e);
  }
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
            startKycVerification();
          },
          child: Text('verify'.tr, style: TextStyle(color: AppPalette.primary)),
        ),
      ],
    ),
  );
  return true;
}
