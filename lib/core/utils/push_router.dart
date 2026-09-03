import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../features/chat/data/chat_repository.dart';
import '../../features/deals/data/deals_repository.dart';
import '../../features/deals/presentation/deal_details_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/posts/data/posts_repository.dart';
import '../../features/posts/presentation/post_details_page.dart';
import '../../features/profile/presentation/become_transporter_page.dart';
import '../../features/profile/presentation/increase_visibility_page.dart';
import '../../features/profile/presentation/wallet_page.dart';
import '../services/session_service.dart';
import 'chat_gate.dart';

/// Opens the screen a tapped push points at.
///
/// The payload only ever carries ids (`{"type": "deal", "deal_id": "42"}`),
/// while the screens want whole models — so each branch fetches its own. That
/// fetch can fail (deleted deal, no network); the notification list is the
/// fallback so a tap always lands somewhere.
///
/// Keys are read in both snake_case and camelCase: the Laravel side sends the
/// former, the broadcast payloads the latter.
Future<void> openFromPush(Map<String, dynamic> data) async {
  if (data.isEmpty) return;

  // A cold start routes before the first frame is up, and a tap can land while
  // a route transition is still running — either way Get has no navigator yet.
  await WidgetsBinding.instance.endOfFrame;
  if (Get.key.currentState == null) return;

  // every target below is account-scoped; a signed-out tap has nowhere to go
  if (Get.find<SessionService>().isGuest) return;

  final type = _str(data, ['type', 'notificationType']);
  final screen = _str(data, ['screen']);

  try {
    // `screen` is the backend's explicit target so it wins — but it names the
    // web front-end's routes, which don't all exist here (`transporter-
    // dashboard` is two separate screens in this app). An unrecognised `screen`
    // therefore falls back to `type` instead of dumping the user in the list.
    for (final key in [screen, type]) {
      if (key != null && await _open(key, data)) return;
    }
  } catch (_) {
    // fetch failed — fall through to the list, which shows the message itself
  }

  Get.to(() => const NotificationsPage());
}

/// Opens whatever screen [key] names. Returns false when it names nothing this
/// app has, or when the payload is missing the id that screen needs — either
/// way the caller moves on to the next key.
Future<bool> _open(String key, Map<String, dynamic> data) async {
  switch (key) {
    case 'deal':
    case 'deal-details':
      final id = _int(data, ['deal_id', 'dealId', 'id']);
      if (id == null) return false;
      final deal = await DealsRepository().getById(id);
      Get.to(() => DealDetailsPage(deal: deal));
      return true;

    // A dispute and a rating both live on the deal's own timeline, so they land
    // on the same screen. Note the missing `id` fallback: on these payloads a
    // bare `id` is the dispute's or the rating's, not the deal's.
    case 'dispute':
    case 'rating':
      final dealId = _int(data, ['deal_id', 'dealId']);
      if (dealId == null) return false;
      final disputed = await DealsRepository().getById(dealId);
      Get.to(() => DealDetailsPage(deal: disputed));
      return true;

    case 'chat':
    case 'chat-room':
    case 'message':
      return _openChat(data);

    case 'trip_match':
    case 'request_match':
    case 'visibility_boost':
    case 'post':
    case 'post-details':
      final id = _int(data, ['post_id', 'postId', 'id']);
      if (id == null) return false;
      final post = await PostsRepository().getById(id);
      Get.to(() => PostDetailsPage(post: post));
      return true;

    case 'payment':
    case 'payment-details':
    case 'payout':
      // there's no standalone receipt screen — a payment always belongs to a
      // deal, and everything else (payouts included) shows up in the wallet
      final dealId = _int(data, ['deal_id', 'dealId']);
      if (dealId == null) {
        Get.to(() => const WalletPage());
        return true;
      }
      final paid = await DealsRepository().getById(dealId);
      Get.to(() => DealDetailsPage(deal: paid));
      return true;

    case 'transporter_verification':
      Get.to(() => const BecomeTransporterPage());
      return true;

    case 'transporter_subscription':
    case 'transporter_boost':
      Get.to(() => const IncreaseVisibilityPage());
      return true;
  }
  return false;
}

/// The chat screen is keyed by the peer, not the chat id, so the inbox is what
/// turns one into the other. Returns false when the thread isn't there (yet).
Future<bool> _openChat(Map<String, dynamic> data) async {
  final chatId = _int(data, ['chat_id', 'chatId']);
  final postId = _int(data, ['post_id', 'postId']);
  if (chatId == null) return false;

  final thread = (await ChatRepository().inbox())
      .firstWhereOrNull((c) => c.chatId == chatId);
  if (thread == null) return false;

  await openChat(thread.user, chatId: chatId, postId: postId);
  return true;
}

// FCM flattens every data value to a string, so ids arrive as "42", not 42.
String? _str(Map<String, dynamic> data, List<String> keys) {
  for (final k in keys) {
    final v = data[k];
    if (v != null && '$v'.isNotEmpty) return '$v';
  }
  return null;
}

int? _int(Map<String, dynamic> data, List<String> keys) {
  final raw = _str(data, keys);
  return raw == null ? null : int.tryParse(raw);
}
