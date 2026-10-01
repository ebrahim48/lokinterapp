import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/profile/presentation/verify_phone_page.dart';
import '../../features/auth/data/auth_repository.dart';
import '../services/session_service.dart';
import '../theme/app_palette.dart';

/// A verified phone number is asked for at EXACTLY TWO moments, and nowhere
/// else:
///
///  1. the sender taps "Confirm agreement & continue"
///  2. the traveler taps "Accept deal"
///
/// Browsing, chatting and posting never ask. Both moments also check identity
/// documents right after — see `requireVerified`.
///
/// Returns true when the number is verified; otherwise it explains why and
/// offers the verification screen, then returns its result.
Future<bool> requirePhoneVerified({String? action}) async {
  final session = Get.find<SessionService>();

  // the cached user can predate a verification done elsewhere (the website, or
  // another device), so ask the server before blocking anyone. `/auth/user` is
  // the authority: phoneVerified true, or a phoneVerifiedAt timestamp.
  if (await _isPhoneVerifiedNow(session)) return true;

  final go = await Get.dialog<bool>(
    AlertDialog(
      title: Text('verify_phone_number'.tr),
      content: Text('phone_needed_to_action'.trParams({'action': action ?? 'action_continue'.tr})),
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

/// Re-reads `/auth/user` and persists it, falling back to the cached value if
/// the call fails — being offline shouldn't lock a verified user out.
Future<bool> _isPhoneVerifiedNow(SessionService session) async {
  try {
    final fresh = await AuthRepository().me();
    return fresh.phoneVerified;
  } catch (_) {
    return session.user.value?.phoneVerified ?? false;
  }
}
