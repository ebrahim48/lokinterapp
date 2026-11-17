import 'package:get/get.dart';

/// Fields the Nov 2026 update added to the deal payload (DealsResource):
/// proposal roles, the single-use delivery QR, pinned pickup/drop-off, Track
/// My Order availability and the transporter's platform fee. Kept apart from
/// [Deal] so the long-standing model stays readable.
class DealExtras {
  /// Server: the signed-in user is the counterparty who may accept (GUIDE §3).
  final bool? canAcceptDeal;

  /// Server: the signed-in user proposed this deal and just waits.
  final bool? isProposer;

  /// First name of whoever proposed it — "Waiting for {name} to accept".
  final String? proposedByName;

  /// Single-use handover token. Sent to the sender (and admins) only; always
  /// null for the transporter so they can't confirm without the recipient.
  final String? deliveryQrToken;

  final String? pickupLocation;
  final double? pickupLat;
  final double? pickupLng;
  final String? dropoffLocation;
  final double? dropoffLat;
  final double? dropoffLng;

  /// Server says this viewer may open Track My Order right now.
  final bool? trackingAvailable;

  /// How often the transporter app should send a position (REQ §6.3).
  final int? trackingIntervalSeconds;

  final String? currency;

  /// Transporter's platform fee for this deal — see [PlatformFee].
  final PlatformFee? platformFee;

  const DealExtras({
    this.canAcceptDeal,
    this.isProposer,
    this.proposedByName,
    this.deliveryQrToken,
    this.pickupLocation,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLocation,
    this.dropoffLat,
    this.dropoffLng,
    this.trackingAvailable,
    this.trackingIntervalSeconds,
    this.currency,
    this.platformFee,
  });

  bool get hasPickupPin => pickupLat != null && pickupLng != null;
  bool get hasDropoffPin => dropoffLat != null && dropoffLng != null;

  factory DealExtras.fromJson(Map<String, dynamic> json) {
    final proposer = json['proposedBy'];
    final track = json['tracking'];
    return DealExtras(
      canAcceptDeal: json['canAcceptDeal'] is bool
          ? json['canAcceptDeal']
          : null,
      isProposer: json['isProposer'] is bool ? json['isProposer'] : null,
      proposedByName: proposer is Map
          ? _str(
              proposer['firstName'] ?? proposer['fullName'] ?? proposer['name'],
            )
          : null,
      deliveryQrToken: _str(
        json['deliveryQrToken'] ?? json['delivery_qr_token'],
      ),
      pickupLocation: _place(json['pickupLocation'] ?? json['pickupAddress']),
      pickupLat: _double(json['pickupLat'] ?? json['pickup_lat']),
      pickupLng: _double(json['pickupLng'] ?? json['pickup_lng']),
      dropoffLocation: _place(
        json['dropoffLocation'] ?? json['dropoffAddress'],
      ),
      dropoffLat: _double(json['dropoffLat'] ?? json['dropoff_lat']),
      dropoffLng: _double(json['dropoffLng'] ?? json['dropoff_lng']),
      trackingAvailable: json['trackingAvailable'] is bool
          ? json['trackingAvailable']
          : (track is Map && track['active'] is bool ? track['active'] : null),
      trackingIntervalSeconds: parseInt(
        json['trackingIntervalSeconds'] ??
            (track is Map ? track['intervalSeconds'] : null),
      ),
      currency: _str(json['currency']),
      platformFee: PlatformFee.tryParse(
        json['platformFee'] ?? json['transporterFee'] ?? json['platform_fee'],
      ),
    );
  }

  static String? _str(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return (s.isEmpty || s == 'null') ? null : s;
  }

  // the API stores "-" for a place nobody filled in
  static String? _place(dynamic v) {
    final s = _str(v);
    return s == '-' ? null : s;
  }

  static double? _double(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

  static int? parseInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}');
}

/// The professional transporter's fee on one completed deal (REQ §7, §8 ·
/// GUIDE Screen 8). Amounts stay strings so "0.900" keeps its three decimals.
class PlatformFee {
  /// False for ordinary travelers — they are never charged.
  final bool applies;

  /// PENDING (dispute/verification open) | FINALIZED | WAIVED | REVERSED
  final String status;

  /// LOCAL | INTERNATIONAL
  final String? ledger;
  final String currency;
  final String amount;
  final int? tierIndex;
  final int? tierFrom;
  final int? tierTo;

  /// CALENDAR_MONTH | ROLLING_90_DAYS
  final String? periodType;
  final int? periodCount;
  final String? nextRate;
  final int? dealsToNextTier;

  const PlatformFee({
    required this.applies,
    this.status = 'FINALIZED',
    this.ledger,
    this.currency = '',
    this.amount = '0',
    this.tierIndex,
    this.tierFrom,
    this.tierTo,
    this.periodType,
    this.periodCount,
    this.nextRate,
    this.dealsToNextTier,
  });

  bool get isLocal =>
      (ledger ?? '').toUpperCase() == 'LOCAL' ||
      currency.toUpperCase() == 'TND';
  bool get isPending => status.toUpperCase() == 'PENDING';

  /// "0.900 TND" / "$2.45 USD"
  String get amountLabel => formatFee(
    amount,
    currency.isEmpty ? (isLocal ? 'TND' : 'USD') : currency,
  );

  String get tierLabel {
    if (tierIndex == null) return '';
    final range = tierTo == null
        ? '${tierFrom ?? ''}+'
        : '${tierFrom ?? ''}-$tierTo';
    return (isLocal ? 'fee_tier_month' : 'fee_tier_90_days').trParams({
      'n': '$tierIndex',
      'range': range,
    });
  }

  static PlatformFee? tryParse(dynamic raw) {
    if (raw is num) {
      return PlatformFee(applies: raw > 0, amount: raw.toString());
    }
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final tier = m['tier'] is Map
        ? Map<String, dynamic>.from(m['tier'])
        : const <String, dynamic>{};
    final period = m['period'] is Map
        ? Map<String, dynamic>.from(m['period'])
        : const <String, dynamic>{};
    final next = m['nextTier'] is Map
        ? Map<String, dynamic>.from(m['nextTier'])
        : const <String, dynamic>{};
    return PlatformFee(
      applies: m['applies'] is bool ? m['applies'] : true,
      status: '${m['status'] ?? 'FINALIZED'}'.toUpperCase(),
      ledger: (m['ledger'] ?? m['ledgerType'])?.toString(),
      currency: '${m['currency'] ?? ''}'.toUpperCase(),
      amount: '${m['amount'] ?? m['fee'] ?? '0'}',
      tierIndex: DealExtras.parseInt(tier['index'] ?? m['tierIndex']),
      tierFrom: DealExtras.parseInt(tier['from']),
      tierTo: DealExtras.parseInt(tier['to']),
      periodType: period['type']?.toString(),
      periodCount: DealExtras.parseInt(period['count'] ?? m['qualifyingCount']),
      nextRate: next['rate']?.toString(),
      dealsToNextTier: DealExtras.parseInt(next['dealsRemaining']),
    );
  }
}

/// TND keeps three decimals ("0.900 TND"), USD two with a dollar sign.
String formatFee(dynamic amount, String currency) {
  final v = amount is num ? amount.toDouble() : double.tryParse('$amount') ?? 0;
  final c = currency.toUpperCase();
  if (c == 'TND') return '${v.toStringAsFixed(3)} TND';
  if (c == 'USD') return '\$${v.toStringAsFixed(2)} USD';
  return '${v.toStringAsFixed(2)} $c'.trim();
}
