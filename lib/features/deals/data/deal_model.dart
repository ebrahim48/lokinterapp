import 'package:flutter/material.dart';
import '../../../core/utils/media_url.dart';
import '../../posts/data/models/post_model.dart';

enum DealStatus { pending, accepted, outgoing, completed, cancelled, disputes }

// Reasons offered when cancelling — the API stores them as codes
// (a live deal came back with "PERSONAL_REASONS").
enum CancelReason {
  packageConcern('PACKAGE_CONCERN', 'Package Concern'),
  tripChanged('TRIP_CHANGED', 'Trip Changed/Cancelled'),
  cantFindItem('CANT_FIND_ITEM', 'Can\'t Find Requested Item'),
  pointsProblem('DELIVERY_PICKUP_POINTS_PROBLEM', 'Delivery/Pickup points problem'),
  paymentConcerns('PAYMENT_CONCERNS', 'Payment Concerns'),
  personalReasons('PERSONAL_REASONS', 'Personal Reasons');

  final String code;
  final String label;
  const CancelReason(this.code, this.label);
}

class Deal {
  final int id;
  final String refId;
  final PostType type;
  final PostLocation location;
  final String fromCountry;
  final String toCountry;
  final DateTime date;
  final double weight;
  final double? profitAmount; // traveler reward
  final DealStatus status;
  final PostUser counterpart;
  final bool isSender;
  final bool isTraveler;
  final String paymentMethod;
  final String? receiverName;
  final String? receiverPhone;
  final String? attachUrl;
  final String? cancelReason;
  // escrow / security deposit
  final bool sdRequired;
  final double? itemEstimatedCost;
  final bool travelerGuaranteeHeld;
  final bool senderFundsHeld;
  final int? countdownSeconds;
  final DateTime? tripDate;
  final DateTime? arrivalDate;
  final bool fundsLockedForDispute;
  final Map<String, dynamic>? dispute;

  const Deal({
    this.id = 0,
    required this.refId,
    required this.type,
    required this.location,
    required this.fromCountry,
    required this.toCountry,
    required this.date,
    required this.weight,
    this.profitAmount,
    required this.status,
    required this.counterpart,
    this.isSender = false,
    this.isTraveler = false,
    this.paymentMethod = '',
    this.receiverName,
    this.receiverPhone,
    this.attachUrl,
    this.cancelReason,
    this.sdRequired = false,
    this.itemEstimatedCost,
    this.travelerGuaranteeHeld = false,
    this.senderFundsHeld = false,
    this.countdownSeconds,
    this.tripDate,
    this.arrivalDate,
    this.fundsLockedForDispute = false,
    this.dispute,
  });

  // Rows from /deals/getAllDeals — a trimmed shape; the same endpoint also
  // returns the user's own posts, which carry flag "POST" instead of "DEAL".
  factory Deal.fromListJson(Map<String, dynamic> json) => Deal(
        id: json['id'] ?? 0,
        refId: '',
        type: PostType.deliver,
        location: json['location'] == 'LOCAL' ? PostLocation.local : PostLocation.international,
        fromCountry: (json['from'] ?? '').toString(),
        toCountry: (json['to'] ?? '').toString(),
        date: _parseDate(json['beforeDate']),
        weight: 0,
        profitAmount: _num(json['profit']),
        status: _status(json['status']),
        counterpart: const PostUser(name: ''),
        paymentMethod: json['paymentMethod'] ?? '',
        countdownSeconds: json['countdownSeconds'],
        fundsLockedForDispute: json['fundsLockedForDispute'] ?? false,
      );

  // Full detail from /deals/getById/{id}
  factory Deal.fromJson(Map<String, dynamic> json) {
    final isTraveler = json['isTraveler'] ?? false;
    // show whoever is on the other side of the agreement
    final otherName =
        (isTraveler ? json['senderName'] : json['travelerName'])?.toString() ?? '';

    return Deal(
      id: json['id'] ?? 0,
      refId: (json['referenceId'] ?? json['id'] ?? '').toString(),
      type: json['type'] == 'TRIP' ? PostType.trip : PostType.deliver,
      location: json['location'] == 'LOCAL' ? PostLocation.local : PostLocation.international,
      fromCountry: (json['from'] ?? '').toString(),
      toCountry: (json['to'] ?? '').toString(),
      date: _parseDate(json['beforeDate']),
      weight: _num(json['weight']) ?? 0,
      profitAmount: _num(json['cost']),
      status: _status(json['status']),
      counterpart: PostUser(name: otherName),
      isSender: json['isSender'] ?? false,
      isTraveler: isTraveler,
      paymentMethod: json['paymentMethod'] ?? '',
      receiverName: json['receiverName'],
      receiverPhone: json['receiverPhone'],
      attachUrl: fixMediaUrl(json['attachLink'] ?? json['attachment']?['url']),
      cancelReason: json['cancelReason'],
      sdRequired: json['sdRequired'] ?? false,
      itemEstimatedCost: _num(json['itemEstimatedCost']),
      travelerGuaranteeHeld: json['travelerGuaranteeHeld'] ?? false,
      senderFundsHeld: json['senderFundsHeld'] ?? false,
      countdownSeconds: json['countdownSeconds'],
      tripDate: _nullableDate(json['tripDate']),
      arrivalDate: _nullableDate(json['arrivalDate']),
      fundsLockedForDispute: json['isLockedByDoubleDispute'] ?? false,
      dispute: json['dispute'] is Map
          ? Map<String, dynamic>.from(json['dispute'])
          : null,
    );
  }

  bool get isLocal => location == PostLocation.local;

  String get profitLabel => profitAmount == null ? '—' : _money(profitAmount!);
  String get depositLabel =>
      itemEstimatedCost == null ? '—' : _money(itemEstimatedCost!);

  // the traveler must put up a card hold before the item moves
  bool get needsGuarantee =>
      sdRequired && isTraveler && !travelerGuaranteeHeld && status == DealStatus.accepted;

  String get paymentLabel => switch (paymentMethod.toUpperCase()) {
        'STRIPE' => 'Pay Online',
        'COD' => 'Cash on delivery',
        '' => '—',
        _ => paymentMethod,
      };

  // reason codes read better as the label the user originally picked
  String? get cancelReasonLabel {
    if (cancelReason == null || cancelReason!.isEmpty) return null;
    for (final r in CancelReason.values) {
      if (r.code == cancelReason) return r.label;
    }
    return cancelReason;
  }

  static String _money(double v) => '\$${v.toStringAsFixed(2)}';

  static double? _num(dynamic v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

  static DealStatus _status(dynamic raw) => switch (raw?.toString().toUpperCase()) {
        'ACCEPTED' => DealStatus.accepted,
        'OUTGOING' => DealStatus.outgoing,
        'COMPLETED' => DealStatus.completed,
        'CANCELED' || 'CANCELLED' || 'REJECTED' => DealStatus.cancelled,
        'DISPUTES' || 'DISPUTE' || 'DISPUTED' => DealStatus.disputes,
        _ => DealStatus.pending,
      };

  static DateTime? _nullableDate(dynamic raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

  // dates arrive as "08/01/2026 06:00 AM" or ISO-8601
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
