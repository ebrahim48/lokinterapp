import 'package:get/get.dart';
import '../../features/posts/data/models/post_model.dart';
import '../../features/chat/presentation/chat_conversation_page.dart';
import 'auth_gate.dart';
import 'notify.dart';
import 'fee_gate.dart';

// Contacting someone only needs a login — identity verification is required
// later, at deal creation (see requireVerified), matching the live app.
Future<void> openChat(PostUser user, {int? postId, int? chatId}) async {
  if (!requireLogin()) return;

  // without a real partner id the API 422s ("A valid chat partner is required")
  if (user.id == 0) {
    toast('still_loading_this_conversation_try_again_in_a_m'.tr);
    return;
  }

  // a NEW conversation about a post is blocked while a fee ledger is
  // overdue; existing threads (inbox, deal chat) always open (REQ §10.2)
  if (chatId == null && postId != null && !await FeeGate.allow(FeeGate.newChat)) return;

  Get.to(() => ChatConversationPage(user: user, postId: postId, chatId: chatId));
}
