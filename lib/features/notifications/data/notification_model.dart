import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';

enum NotifType { deal, chat, trip, request, verification }

class AppNotification {
  final NotifType type;
  final String title;
  final String body;
  final String time;
  final bool read;

  const AppNotification({
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });
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

const mockNotifications = <AppNotification>[
  AppNotification(
    type: NotifType.trip,
    title: 'New trip to Tunisia',
    body: 'A traveler is arriving in Tunis on 12 June with 10 kg available.',
    time: '5m',
  ),
  AppNotification(
    type: NotifType.chat,
    title: 'Ahmed R. sent a message',
    body: 'Deal! I will send the agreement now.',
    time: '12m',
  ),
  AppNotification(
    type: NotifType.deal,
    title: 'Agreement accepted',
    body: 'Your agreement on LK-2041 was confirmed by both parties.',
    time: '1h',
    read: true,
  ),
  AppNotification(
    type: NotifType.verification,
    title: 'Identity verified',
    body: 'Your identity documents were approved.',
    time: 'Yesterday',
    read: true,
  ),
];
