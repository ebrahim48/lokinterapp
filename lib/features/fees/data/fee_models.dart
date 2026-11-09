import 'package:get/get.dart';

import '../../../core/utils/format.dart';
import '../../deals/data/deal_extras.dart' show formatFee;

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
int? _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
DateTime? _date(dynamic v) {
  final s = '${v ?? ''}'.trim();
  return s.isEmpty || s == 'null' ? null : parseServerDate(s);
}

/// ACTIVE · PAYMENT_REQUIRED · OVERDUE (REQ §10)
enum LedgerStatus { active, paymentRequired, overdue }

/// One of the transporter's two independent fee ledgers (REQ §9):
/// Tunisia local in TND (15 TND threshold, calendar month) and international
/// in USD ($25 threshold, rolling 90 days). Never combined or converted.
class FeeLedger {
  final String currency; // TND | USD
  final double threshold;
  final double currentBalance; // unpaid, not yet covered by a payment request
  final double frozenBalance; // covered by an open payment request
  final double totalDue;
  final LedgerStatus status;
  final DateTime? dueAt;
  // loyalty / tier progress, when the API sends it
  final int? qualifyingCount;
  final String? currentRate;
  final String? nextRate;
  final int? dealsToNextTier;

  const FeeLedger({
    required this.currency,
    required this.threshold,
    required this.currentBalance,
    required this.frozenBalance,
    required this.totalDue,
    required this.status,
    this.dueAt,
    this.qualifyingCount,
    this.currentRate,
    this.nextRate,
    this.dealsToNextTier,
  });

  bool get isLocal => currency == 'TND';
  bool get isOverdue => status == LedgerStatus.overdue;
  bool get paymentRequired => status != LedgerStatus.active;

  /// Share of the threshold reached — can pass 1.0 (the full balance is due).
  double get progress => threshold <= 0 ? 0 : totalDue / threshold;

  String money(double v) => formatFee(v, currency);

  String get title => isLocal ? 'tunisia_local_ledger'.tr : 'international_ledger'.tr;

  /// Whole days left before restrictions (GUIDE Screen 9.1); 0 once due.
  int? get daysLeft {
    final d = dueAt;
    if (d == null) return null;
    final left = d.difference(DateTime.now());
    if (left.isNegative) return 0;
    return (left.inHours / 24).ceil();
  }

  factory FeeLedger.fromJson(Map<String, dynamic> j, {String? fallbackCurrency}) {
    final currency = '${j['currency'] ?? fallbackCurrency ?? ''}'.toUpperCase();
    final current = _d(j['currentBalance'] ?? j['balance'] ?? j['unpaidBalance']);
    final frozen = _d(j['frozenBalance'] ?? j['frozenAmount']);
    final total = j['totalDue'] != null ? _d(j['totalDue']) : current + frozen;
    final raw = '${j['status'] ?? ''}'.toUpperCase();
    final status = (j['isOverdue'] == true || raw == 'OVERDUE')
        ? LedgerStatus.overdue
        : (raw == 'PAYMENT_REQUIRED' ? LedgerStatus.paymentRequired : LedgerStatus.active);
    final pr = j['paymentRequest'] is Map ? Map<String, dynamic>.from(j['paymentRequest']) : null;
    final loyalty = j['loyalty'] is Map ? Map<String, dynamic>.from(j['loyalty']) : null;
    final next = loyalty?['nextTier'] is Map
        ? Map<String, dynamic>.from(loyalty!['nextTier'])
        : (j['nextTier'] is Map ? Map<String, dynamic>.from(j['nextTier']) : null);
    return FeeLedger(
      currency: currency,
      threshold: _d(j['threshold'] ?? (currency == 'TND' ? 15 : 25)),
      currentBalance: current,
      frozenBalance: frozen,
      totalDue: total,
      status: status,
      dueAt: _date(j['dueAt'] ?? pr?['dueAt'] ?? j['deadline']),
      qualifyingCount: _i(loyalty?['count'] ?? j['qualifyingCount'] ?? j['qualifyingDeals']),
      currentRate: (loyalty?['currentRate'] ?? j['currentRate'])?.toString(),
      nextRate: next?['rate']?.toString(),
      dealsToNextTier: _i(next?['dealsRemaining']),
    );
  }
}

class LedgerSummary {
  final bool isOverdue;
  final List<FeeLedger> ledgers;
  const LedgerSummary({required this.isOverdue, required this.ledgers});

  FeeLedger? get local => ledgers.firstWhereOrNull((l) => l.isLocal);
  FeeLedger? get international => ledgers.firstWhereOrNull((l) => !l.isLocal);

  /// Reads `data.ledgers[]`, falling back to the keyed shape
  /// (`local_tunisia_ledger` / `international_ledger`).
  factory LedgerSummary.fromJson(dynamic data) {
    if (data is! Map) return const LedgerSummary(isOverdue: false, ledgers: []);
    final list = <FeeLedger>[];
    final raw = data['ledgers'];
    if (raw is List && raw.isNotEmpty) {
      for (final e in raw.whereType<Map>()) {
        list.add(FeeLedger.fromJson(Map<String, dynamic>.from(e)));
      }
    } else {
      for (final (key, cur) in [('local_tunisia_ledger', 'TND'), ('international_ledger', 'USD')]) {
        final l = data[key];
        if (l is Map) {
          list.add(FeeLedger.fromJson(Map<String, dynamic>.from(l), fallbackCurrency: cur));
        }
      }
    }
    // local first, like the GUIDE mock-up
    list.sort((a, b) => (a.isLocal ? 0 : 1).compareTo(b.isLocal ? 0 : 1));
    return LedgerSummary(
      isOverdue: data['is_overdue'] == true ||
          data['isOverdue'] == true ||
          list.any((l) => l.isOverdue),
      ledgers: list,
    );
  }
}

/// What `initiate-settlement` hands back: a Stripe intent to confirm in the
/// app, or bank-transfer details to pay outside it.
class Settlement {
  final String? id;
  final double amount;
  final String currency;
  final String? clientSecret;
  final String? paymentIntentId;
  final Map<String, dynamic>? bankDetails;

  const Settlement({
    this.id,
    required this.amount,
    required this.currency,
    this.clientSecret,
    this.paymentIntentId,
    this.bankDetails,
  });

  bool get isStripe => (clientSecret ?? '').isNotEmpty;

  factory Settlement.fromJson(Map<String, dynamic> j, String currency) {
    final bank = j['bankDetails'] ?? j['bank_details'] ?? j['bankTransfer'];
    return Settlement(
      id: (j['settlementId'] ?? j['id'] ?? j['paymentId'])?.toString(),
      amount: _d(j['amount'] ?? j['totalDue']),
      currency: '${j['currency'] ?? currency}'.toUpperCase(),
      clientSecret: (j['clientSecret'] ?? j['client_secret'])?.toString(),
      paymentIntentId: (j['paymentIntentId'] ?? j['payment_intent_id'])?.toString(),
      bankDetails: bank is Map ? Map<String, dynamic>.from(bank) : null,
    );
  }
}

/// A consolidated fee invoice (REQ §15.1). Deliberately carries no deal
/// numbers, customer names or shipment contents.
class FeeInvoice {
  final int id;
  final String number;
  final String description;
  final double total;
  final double? tax;
  final String currency;
  final DateTime? paidAt;
  final String status;
  final String? paymentReference;

  const FeeInvoice({
    required this.id,
    required this.number,
    required this.description,
    required this.total,
    this.tax,
    required this.currency,
    this.paidAt,
    required this.status,
    this.paymentReference,
  });

  bool get isPaid => status.toUpperCase() == 'PAID';
  String get totalLabel => formatFee(total, currency);

  factory FeeInvoice.fromJson(Map<String, dynamic> j) => FeeInvoice(
        id: _i(j['id']) ?? 0,
        number: '${j['invoiceNumber'] ?? j['number'] ?? j['invoice_number'] ?? ''}',
        description: '${j['description'] ?? j['serviceDescription'] ?? 'Lokinter Platform Service & Operating Fees'}',
        total: _d(j['totalAmount'] ?? j['total'] ?? j['amount'] ?? j['amountPaid']),
        tax: (j['tax'] ?? j['taxAmount']) != null ? _d(j['tax'] ?? j['taxAmount']) : null,
        currency: '${j['currency'] ?? ''}'.toUpperCase(),
        paidAt: _date(j['paymentDate'] ?? j['paidAt'] ?? j['issuedAt'] ?? j['createdAt']),
        status: '${j['status'] ?? 'PAID'}'.toUpperCase(),
        paymentReference: (j['paymentReference'] ?? j['payment_reference'])?.toString(),
      );
}
