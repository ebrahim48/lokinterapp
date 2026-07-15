import 'package:flutter/material.dart';
import '../../posts/data/models/post_model.dart';

enum DealStatus { pending, accepted, outgoing, completed, cancelled, disputes }

class Deal {
  final int id;
  final String refId;
  final PostType type;
  final PostLocation location;
  final String fromCountry;
  final String toCountry;
  final String? fromIso;
  final DateTime date;
  final double weight;
  final String profit; // formatted, e.g. "USD 50.00"
  final DealStatus status;
  final PostUser counterpart;
  final bool isSender; // which side of the agreement am I on
  final String? disputeReason;
  // agreed terms finalised in chat
  final String paymentMethod;
  final String agreedWeight;
  final String? receiverName;

  const Deal({
    this.id = 0,
    required this.refId,
    required this.type,
    required this.location,
    required this.fromCountry,
    required this.toCountry,
    this.fromIso,
    required this.date,
    required this.weight,
    required this.profit,
    required this.status,
    required this.counterpart,
    this.isSender = true,
    this.disputeReason,
    this.paymentMethod = '—',
    this.agreedWeight = '',
    this.receiverName,
  });

  factory Deal.fromJson(Map<String, dynamic> json) {
    final post = Map<String, dynamic>.from(json['post'] ?? {});
    final isSender = json['isSender'] ?? true;
    // show the other side of the agreement
    final other = Map<String, dynamic>.from(
      (isSender ? json['traveler'] : json['sender']) ?? json['user'] ?? {},
    );
    // numbers can arrive as strings, same as on posts
    final weight =
        double.tryParse((json['weight'] ?? post['weight'] ?? 0).toString()) ?? 0;
    final cost = json['cost'];

    return Deal(
      id: json['id'] ?? 0,
      refId: (json['referenceId'] ?? json['reference_id'] ?? json['id'] ?? '').toString(),
      type: (json['type'] ?? post['type']) == 'TRIP' ? PostType.trip : PostType.deliver,
      location: (json['location'] ?? post['location']) == 'LOCAL'
          ? PostLocation.local
          : PostLocation.international,
      fromCountry: _place(json['fromCountry'] ?? post['fromCountry']),
      toCountry: _place(json['toCountry'] ?? post['toCountry']),
      fromIso: _iso(json['fromCountry'] ?? post['fromCountry']),
      date: _parseDate(json['tripDate'] ?? json['beforeDate'] ?? post['beforeDate']),
      weight: weight,
      profit: cost == null ? '—' : '${json['currency'] ?? 'USD'} $cost',
      status: _status(json['status']),
      counterpart: PostUser.fromJson(other),
      isSender: isSender,
      disputeReason: json['disputeReason'] ?? json['cancelReason'],
      paymentMethod: json['paymentMethod'] ?? '—',
      agreedWeight: '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} kg',
      receiverName: json['receiverName'],
    );
  }

  bool get isLocal => location == PostLocation.local;

  static String _place(dynamic v) => v is Map ? (v['name'] ?? '') : (v?.toString() ?? '');
  static String? _iso(dynamic v) => v is Map ? v['iso2'] : null;

  static DealStatus _status(dynamic raw) => switch (raw?.toString().toUpperCase()) {
        'ACCEPTED' => DealStatus.accepted,
        'OUTGOING' => DealStatus.outgoing,
        'COMPLETED' => DealStatus.completed,
        'CANCELED' || 'CANCELLED' || 'REJECTED' => DealStatus.cancelled,
        'DISPUTES' || 'DISPUTE' || 'DISPUTED' => DealStatus.disputes,
        _ => DealStatus.pending,
      };

  // dates arrive as "07/20/2026 12:00 AM" or "2026-07-20"
  static DateTime _parseDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return DateTime.now();
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;
    try {
      final d = raw.split(' ')[0].split('/');
      return DateTime(int.parse(d[2]), int.parse(d[0]), int.parse(d[1]));
    } catch (_) {
      return DateTime.now();
    }
  }
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

  // what /deals/getAllDeals expects in ?status=
  String get apiValue => switch (this) {
        DealStatus.pending => 'PENDING',
        DealStatus.accepted => 'ACCEPTED',
        DealStatus.outgoing => 'OUTGOING',
        DealStatus.completed => 'COMPLETED',
        DealStatus.cancelled => 'CANCELED',
        DealStatus.disputes => 'DISPUTES',
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
