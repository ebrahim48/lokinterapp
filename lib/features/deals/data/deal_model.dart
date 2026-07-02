import 'package:flutter/material.dart';
import '../../posts/data/models/post_model.dart';

enum DealStatus { pending, accepted, outgoing, completed, cancelled, disputes }

class Deal {
  final String refId;
  final PostType type;
  final PostLocation location;
  final String fromCountry;
  final String toCountry;
  final DateTime date;
  final double weight;
  final String profit; // formatted, e.g. "TND 50.000"
  final DealStatus status;
  final PostUser counterpart;
  final String? disputeReason;

  const Deal({
    required this.refId,
    required this.type,
    required this.location,
    required this.fromCountry,
    required this.toCountry,
    required this.date,
    required this.weight,
    required this.profit,
    required this.status,
    required this.counterpart,
    this.disputeReason,
  });

  bool get isLocal => location == PostLocation.local;
}

extension DealStatusX on DealStatus {
  String get label => switch (this) {
        DealStatus.pending => 'Pending',
        DealStatus.accepted => 'Accepted',
        DealStatus.outgoing => 'Outgoing',
        DealStatus.completed => 'Completed',
        DealStatus.cancelled => 'Cancelled',
        DealStatus.disputes => 'Dispute',
      };

  // (background, foreground) — tints mirror the web deals list
  (Color, Color) get colors => switch (this) {
        DealStatus.pending => (const Color(0xFFFEF9C3), const Color(0xFF854D0E)),
        DealStatus.accepted => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
        DealStatus.outgoing => (const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
        DealStatus.completed => (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
        DealStatus.cancelled => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
        DealStatus.disputes => (const Color(0xFFFFF1F2), const Color(0xFFBE123C)),
      };
}
