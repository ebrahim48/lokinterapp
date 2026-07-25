import 'package:get/get.dart';
import '../../features/posts/data/models/post_model.dart';
import '../../features/chat/presentation/chat_conversation_page.dart';
import 'auth_gate.dart';
import 'notify.dart';

// Contacting someone only needs a login — identity verification is required
// later, at deal creation (see requireVerified), matching the live app.
Future<void> openChat(PostUser user, {int? postId, int? chatId}) async {
  if (!requireLogin()) return;

  // without a real partner id the API 422s ("A valid chat partner is required")
  if (user.id == 0) {
    toast('Still loading this conversation — try again in a moment');
    return;
  }

  Get.to(() => ChatConversationPage(user: user, postId: postId, chatId: chatId));
}
