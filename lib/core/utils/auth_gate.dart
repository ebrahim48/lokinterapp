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
      title: const Text('Login required'),
      content: const Text('Sign in to chat, post and manage deals.'),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Not now')),
        TextButton(
          onPressed: () {
            Get.back();
            Get.to(() => const LoginPage());
          },
          child: const Text('Login', style: TextStyle(color: AppPalette.primary)),
        ),
      ],
    ),
  );
  return false;
}
