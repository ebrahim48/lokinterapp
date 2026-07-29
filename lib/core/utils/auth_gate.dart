import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/auth/presentation/login_page.dart';
import '../services/session_service.dart';
import '../theme/app_palette.dart';

// Guests can browse; anything that talks to the account goes through this.
// Returns true when the caller may proceed.
bool requireLogin() {
  if (Get.find<SessionService>().loggedIn) return true;
  Get.dialog(
    AlertDialog(
      title: Text('login_required'.tr),
      content: Text('sign_in_to_chat_post_and_manage_deals'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('not_now'.tr)),
        TextButton(
          onPressed: () {
            Get.back();
            Get.to(() => const LoginPage());
          },
          child: Text('login'.tr, style: TextStyle(color: AppPalette.primary)),
        ),
      ],
    ),
  );
  return false;
}
