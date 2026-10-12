import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';

enum NotifType { deal, chat, trip, request, verification }

class AppNotification {
  final String id;
  final NotifType type;
  final String title;
  final String body;
  final String time;
  final bool read;
  /// Raw type string from the backend — used to filter and deduplicate.
  final String? rawType;
  /// Deal/post ID extracted from the payload — used to deduplicate events
  /// that fire multiple notifications for the same deal status change.
  final int? dealId;

  const AppNotification({
    this.id = '',
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
    this.rawType,
    this.dealId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '').toString();
    final rawType = (json['type'] ?? json['notificationType'] ?? '').toString();

    // dealId may be nested inside a `data` or `metadata` object, or at root
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    final meta = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : <String, dynamic>{};
    final rawDealId = json['dealId'] ??
        data['dealId'] ??
        meta['dealId'] ??
        json['deal_id'] ??
        data['deal_id'] ??
        meta['deal_id'];
    final dealId = rawDealId is int
        ? rawDealId
        : int.tryParse('${rawDealId ?? ''}');

    return AppNotification(
      id: (json['id'] ?? '').toString(),
      type: _typeFor(title, rawType),
      title: title,
      body: (json['subtitle'] ?? json['body'] ?? json['message'] ?? '').toString(),
      time: (json['createdAt'] ?? json['created_at'] ?? '').toString(),
      read: json['read_at'] != null || json['readAt'] != null,
      rawType: rawType.isEmpty ? null : rawType,
      dealId: dealId,
    );
  }

  /// True for notifications that are already shown in the chat inbox — never
  /// show these as a second row in the notifications list.
  bool get isChatSystemMessage {
    final t = (rawType ?? '').toLowerCase();
    return t == 'chat_message' ||
        t == 'system_message' ||
        t == 'chat_system' ||
        t == 'new_message';
  }

  /// Deduplication key: same deal + same event title on the same calendar day.
  ///
  /// When the backend fires two notifications for the same deal status change
  /// (e.g. "Deal status updated, rejected" and "Deal status has been changed to
  /// rejected"), this key collapses them into one. The notification with the
  /// lower id (earlier) is kept; the later one is dropped.
  String? get _dedupKey {
    final did = dealId;
    if (did == null || did == 0) return null;
    // Normalise the title to a keyword so minor wording differences still match.
    final titleKey = _normaliseDealTitle(title);
    // Use just the date portion (YYYY-MM-DD) so duplicates arriving within the
    // same day collapse regardless of exact timestamp.
    final dateKey = time.length >= 10 ? time.substring(0, 10) : time;
    return 'deal_${did}_${titleKey}_$dateKey';
  }

  static String _normaliseDealTitle(String title) {
    final t = title.toLowerCase();
    // checked first: a decision title often also says "completed"/"cancelled"
    // ("Dispute resolved — deal completed"), and the admin's decision fires
    // two notifications with different wording for the same event
    final isDispute = t.contains('dispute') || t.contains('litige');
    if (isDispute || t.contains('decision') || t.contains('décision')) {
      final decided = t.contains('resolv') ||
          t.contains('résolu') ||
          t.contains('decision') ||
          t.contains('décision') ||
          t.contains('closed') ||
          t.contains('clôtur');
      if (decided) return 'dispute_decision';
    }
    if (t.contains('reject') || t.contains('refus')) return 'rejected';
    if (t.contains('accept') || t.contains('approv')) return 'accepted';
    if (t.contains('cancel') || t.contains('annul')) return 'cancelled';
    if (t.contains('complet') || t.contains('terminé')) return 'completed';
    if (t.contains('status') || t.contains('statut')) return 'status_change';
    if (t.contains('paid') || t.contains('payé') || t.contains('payment')) return 'payment';
    if (t.contains('dispute') || t.contains('litige')) return 'dispute';
    return t.replaceAll(RegExp(r'\s+'), '_').substring(
        0, t.length > 30 ? 30 : t.length);
  }

  // the API doesn't always send a category, so the icon is guessed from
  // the title and rawType
  static NotifType _typeFor(String title, String rawType) {
    final t = title.toLowerCase();
    final rt = rawType.toLowerCase();
    if (rt.contains('chat') || rt.contains('message') ||
        t.contains('message') || t.contains('chat')) return NotifType.chat;
    if (rt.contains('trip') || t.contains('trip')) return NotifType.trip;
    if (rt.contains('request') || t.contains('request') ||
        t.contains('demande')) return NotifType.request;
    if (t.contains('identity') || t.contains('verif') ||
        t.contains('identit') || rt.contains('verif')) return NotifType.verification;
    return NotifType.deal;
  }
}

extension NotifTypeX on NotifType {
  IconData get icon => switch (this) {
        NotifType.deal => Icons.handshake_outlined,
        NotifType.chat => Icons.chat_bubble_outline,
        NotifType.trip => Icons.flight_takeoff,
        NotifType.request => Icons.inventory_2_outlined,
        NotifType.verification => Icons.verified_outlined,
      };

  Color get color => switch (this) {
        NotifType.deal => AppPalette.verified,
        NotifType.chat => AppPalette.intlAccent,
        NotifType.trip => AppPalette.primary,
        NotifType.request => AppPalette.primary,
        NotifType.verification => AppPalette.localAccent,
      };
}

/// Removes duplicate deal-status notifications.
///
/// The backend sometimes fires two notifications for the same deal event.
/// This function keeps the first occurrence of each [dedupKey] and drops the
/// rest so the list shows exactly one row per event.
List<AppNotification> deduplicateNotifications(List<AppNotification> raw) {
  final seen = <String>{};
  final result = <AppNotification>[];
  for (final n in raw) {
    final key = n._dedupKey;
    if (key == null) {
      // no deal ID → not a duplicate candidate, always keep
      result.add(n);
    } else if (seen.add(key)) {
      // first time seeing this key → keep
      result.add(n);
      // subsequent ones with the same key are dropped
    }
  }
  return result;
}
