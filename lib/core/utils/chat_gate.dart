import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/posts/data/models/post_model.dart';
import '../../features/profile/data/kyc_repository.dart';
import '../../features/profile/presentation/basic_info_page.dart';
import '../../features/chat/presentation/chat_conversation_page.dart';
import '../exceptions/app_exceptions.dart';
import '../theme/app_palette.dart';
import 'auth_gate.dart';
import 'notify.dart';

// Chat is gated on identity verification: check KYC first, and send
// unverified users to their profile instead of into a conversation.
Future<void> openChat(PostUser user, {int? postId, int? chatId}) async {
  if (!requireLogin()) return;

  KycStatus kyc;
  try {
    kyc = await KycRepository().status();
  } on AppException catch (e) {
    toastError(e);
    return;
  }

  if (!kyc.verified) {
    Get.dialog(
      AlertDialog(
        title: const Text('Verify your identity'),
        content: Text(kyc.message),
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
    return;
  }

  Get.to(() => ChatConversationPage(user: user, postId: postId, chatId: chatId));
}
