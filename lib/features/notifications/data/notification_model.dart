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

  const AppNotification({
    this.id = '',
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '').toString();
    return AppNotification(
      id: (json['id'] ?? '').toString(),
      type: _typeFor(title),
      title: title,
      body: json['subtitle'] ?? json['body'] ?? '',
      time: (json['createdAt'] ?? json['created_at'] ?? '').toString(),
      read: json['read_at'] != null || json['readAt'] != null,
    );
  }

  // the API doesn't send a category, so the icon is guessed from the title
  static NotifType _typeFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('message') || t.contains('chat')) return NotifType.chat;
    if (t.contains('trip')) return NotifType.trip;
    if (t.contains('request')) return NotifType.request;
    if (t.contains('identity') || t.contains('verif')) return NotifType.verification;
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
