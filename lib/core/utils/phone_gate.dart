import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/profile/presentation/verify_phone_page.dart';
import '../services/session_service.dart';
import '../theme/app_palette.dart';

/// A verified phone number is required before a user can talk to anyone or
/// enter an agreement — messaging, posting, and deal creation all go through
/// here. Returns true when the number is verified; otherwise it explains why
/// and offers the verification screen, then returns false.
///
/// Identity documents are a separate, later gate — see `requireVerified`.
Future<bool> requirePhoneVerified({String action = 'continue'}) async {
  final user = Get.find<SessionService>().user.value;
  if (user?.phoneVerified ?? false) return true;

  final go = await Get.dialog<bool>(
    AlertDialog(
      title: Text('verify_phone_number'.tr),
      content: Text('phone_needed_to_action'.trParams({'action': action})),
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
  if (go != true) return false;

  // the screen writes the verified user into the session, so this returns
  // true and the caller can carry straight on with what it was doing
  return VerifyPhonePage.open();
}
