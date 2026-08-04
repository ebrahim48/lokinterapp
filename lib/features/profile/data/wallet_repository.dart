import 'package:get/get.dart';
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/data_bus.dart';

/// Money the traveler has coming but cannot withdraw yet. Every one of these
/// stays visible with the reason it is still held — only the available balance
/// reflects what is actually withdrawable.
class WalletEarning {
  final int dealId;
  final String dealRef;
  final String dealStatus;
  final double amount;
  final double profit;
  final double itemCost;
  /// e.g. "Waiting for the dispute window to close"
  final String statusLabel;
  final DateTime? releaseAt;
  final int? countdownSeconds;

  const WalletEarning({
    required this.dealId,
    this.dealRef = '',
    this.dealStatus = '',
    required this.amount,
    this.profit = 0,
    this.itemCost = 0,
    this.statusLabel = '',
    this.releaseAt,
    this.countdownSeconds,
  });

  factory WalletEarning.fromJson(Map<String, dynamic> e) => WalletEarning(
        dealId: e['dealId'] ?? 0,
        dealRef: '${e['dealRef'] ?? ''}',
        dealStatus: '${e['dealStatus'] ?? ''}',
        amount: double.tryParse('${e['amount'] ?? 0}') ?? 0,
        profit: double.tryParse('${e['profit'] ?? 0}') ?? 0,
        itemCost: double.tryParse('${e['itemCost'] ?? 0}') ?? 0,
        statusLabel: '${e['statusLabel'] ?? e['reason'] ?? ''}',
        releaseAt: DateTime.tryParse('${e['releaseAt'] ?? ''}'),
        countdownSeconds: e['countdownSeconds'] is num
            ? (e['countdownSeconds'] as num).toInt()
            : null,
      );

  /// "5h 20m left" while the hold is still counting down.
  String? get countdownText {
    final s = countdownSeconds;
    if (s == null || s <= 0) return null;
    final h = s ~/ 3600, m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m left' : '${m}m left';
  }
}

/// A guarantee that was charged, refunded or is held because of a dispute.
class WalletDispute {
  final int dealId;
  final String dealRef;
  final double amountCharged;
  final String statusLabel;
  final String reason;
  final String status;

  const WalletDispute({
    required this.dealId,
    this.dealRef = '',
    this.amountCharged = 0,
    this.statusLabel = '',
    this.reason = '',
    this.status = '',
  });

  factory WalletDispute.fromJson(Map<String, dynamic> e) => WalletDispute(
        dealId: e['dealId'] ?? 0,
        dealRef: '${e['dealRef'] ?? ''}',
        amountCharged: double.tryParse('${e['amountCharged'] ?? 0}') ?? 0,
        statusLabel: '${e['statusLabel'] ?? ''}',
        reason: '${e['reason'] ?? ''}',
        status: '${e['status'] ?? ''}',
      );
}

class WalletData {
  final double available;
  final double totalPending;
  final double lifetimeEarnings;
  final String currency;
  final bool hasStripeConnect;
  /// Everything still owed to the traveler, each with why it is held.
  final List<WalletEarning> potential;
  final List<WalletDispute> disputes;

  const WalletData({
    this.available = 0,
    this.totalPending = 0,
    this.lifetimeEarnings = 0,
    this.currency = 'USD',
    this.hasStripeConnect = false,
    this.potential = const [],
    this.disputes = const [],
  });

  factory WalletData.fromJson(Map<String, dynamic> json) => WalletData(
        available: ((json['available'] ?? 0) as num).toDouble(),
        totalPending: ((json['totalPending'] ?? 0) as num).toDouble(),
        lifetimeEarnings: ((json['lifetimeEarnings'] ?? 0) as num).toDouble(),
        currency: json['currency'] ?? 'USD',
        hasStripeConnect: json['hasStripeConnect'] ?? false,
        potential: [
          for (final e in (json['potentialEarningsList'] as List? ??
                  json['recentEarnings'] as List? ??
                  const [])
              .whereType<Map>())
            WalletEarning.fromJson(Map<String, dynamic>.from(e)),
        ],
        disputes: [
          for (final e in (json['disputeHistory'] as List? ?? const [])
              .whereType<Map>())
            WalletDispute.fromJson(Map<String, dynamic>.from(e)),
        ],
      );
}

class PayoutMethod {
  final int id;
  final String label;
  final String type; // STRIPE | PAYPAL | WISE
  final bool isDefault;

  const PayoutMethod({
    required this.id,
    required this.label,
    this.type = '',
    this.isDefault = false,
  });

  factory PayoutMethod.fromJson(Map<String, dynamic> json) => PayoutMethod(
        id: json['id'] ?? 0,
        type: (json['type'] ?? json['provider'] ?? '').toString().toUpperCase(),
        isDefault: json['isDefault'] ?? json['is_default'] ?? false,
        label: [
          json['type'] ?? json['provider'] ?? 'Account',
          json['last4'] != null ? '•••• ${json['last4']}' : (json['email'] ?? ''),
        ].where((s) => s.toString().isNotEmpty).join(' '),
      );
}

/// One row of the wallet ledger (`/wallet/transactions`). Types mirror the
/// backend enum: credit / debit / refund / reserve / release /
/// external_credit / external_debit.
class WalletTransaction {
  final int id;
  final String type;
  final double amount;
  final double balanceAfter;
  final String description;
  final DateTime? createdAt;
  /// Why the money moved, and where the entry stands.
  final String statusLabel;
  final String reason;
  final int dealId;
  final String dealRef;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    this.createdAt,
    this.statusLabel = '',
    this.reason = '',
    this.dealId = 0,
    this.dealRef = '',
  });

  bool get isCredit =>
      type == 'credit' || type == 'refund' || type == 'release' || type == 'external_credit';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] ?? 0,
        type: (json['type'] ?? '').toString(),
        amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
        balanceAfter: double.tryParse('${json['balanceAfter'] ?? json['balance_after'] ?? 0}') ?? 0,
        description: (json['description'] ?? '').toString(),
        createdAt: DateTime.tryParse(
            '${json['dateTime'] ?? json['createdAt'] ?? json['created_at'] ?? ''}'),
        statusLabel: '${json['statusLabel'] ?? ''}',
        reason: '${json['reason'] ?? ''}',
        dealId: json['dealId'] ?? 0,
        dealRef: '${json['dealRef'] ?? ''}',
      );
}

/// A withdrawal request and where it stands (`/wallet/payout-requests`).
class PayoutRequestRow {
  final int id;
  final String method;
  final double amount;
  final double feeAmount;
  final double netAmount;
  final String currency;
  final String status; // processing/fulfilled/failed/pending_admin_review/approved/declined
  final DateTime? requestedAt;

  const PayoutRequestRow({
    required this.id,
    required this.method,
    required this.amount,
    required this.feeAmount,
    required this.netAmount,
    required this.currency,
    required this.status,
    this.requestedAt,
  });

  factory PayoutRequestRow.fromJson(Map<String, dynamic> json) =>
      PayoutRequestRow(
        id: json['id'] ?? 0,
        method: (json['method'] ?? '').toString(),
        amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
        feeAmount: double.tryParse('${json['feeAmount'] ?? json['fee_amount'] ?? 0}') ?? 0,
        netAmount: double.tryParse('${json['netAmount'] ?? json['net_amount'] ?? 0}') ?? 0,
        currency: (json['currency'] ?? 'USD').toString(),
        status: (json['status'] ?? '').toString(),
        requestedAt: DateTime.tryParse('${json['requestedAt'] ?? json['requested_at'] ?? json['created_at'] ?? ''}'),
      );
}

/// Fee preview returned by `/wallet/payout-requests/quote` before the user
/// commits to a withdrawal (website shows this under the amount field).
class PayoutQuote {
  final double amount;
  final double feeAmount;
  final double netAmount;
  final String currency;

  const PayoutQuote({
    required this.amount,
    required this.feeAmount,
    required this.netAmount,
    required this.currency,
  });

  factory PayoutQuote.fromJson(Map<String, dynamic> json) => PayoutQuote(
        amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
        feeAmount: double.tryParse('${json['feeAmount'] ?? json['fee_amount'] ?? 0}') ?? 0,
        netAmount: double.tryParse('${json['netAmount'] ?? json['net_amount'] ?? 0}') ?? 0,
        currency: (json['currency'] ?? 'USD').toString(),
      );
}

/// Stripe Connect account state (`/stripe-connect/status`).
class StripeConnectStatus {
  final bool connected;
  final String status; // none|onboarding|active|restricted
  final bool canReceivePayments;

  const StripeConnectStatus({
    this.connected = false,
    this.status = 'none',
    this.canReceivePayments = false,
  });

  factory StripeConnectStatus.fromJson(Map<String, dynamic> json) =>
      StripeConnectStatus(
        connected: json['connected'] ?? false,
        status: (json['status'] ?? 'none').toString(),
        canReceivePayments: json['canReceivePayments'] ?? false,
      );
}

class WalletRepository {
  final _api = Get.find<ApiService>();

  Future<WalletData> dashboard() async {
    final res = await _api.get('/wallet/');
    return WalletData.fromJson(Map<String, dynamic>.from(unwrapData(res)));
  }

  Future<List<WalletTransaction>> transactions({int page = 1, int limit = 50}) async {
    final res = await _api.get('/wallet/transactions',
        queryParameters: {'page': page, 'limit': limit});
    final data = unwrapData(res);
    final raw = data is Map ? (data['list'] ?? data['transactions'] ?? []) : (data ?? []);
    return (raw as List)
        .whereType<Map>()
        .map((e) => WalletTransaction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<PayoutMethod>> payoutMethods() async {
    final res = await _api.get('/wallet/payout-methods');
    final data = unwrapData(res);
    final raw = data is Map ? (data['list'] ?? []) : (data ?? []);
    return (raw as List)
        .whereType<Map>()
        .map((e) => PayoutMethod.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Fee preview — call before [requestPayout] so the user sees the net.
  Future<PayoutQuote> quotePayout(int methodId, double amount, String currency) async {
    final data = unwrapData(await _api.post('/wallet/payout-requests/quote', data: {
      'payoutMethodId': methodId,
      'amount': amount,
      'currency': currency,
    }));
    return PayoutQuote.fromJson(
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
  }

  Future<void> requestPayout(int methodId, double amount, String currency) async {
    unwrapData(await _api.post('/wallet/payout-requests', data: {
      'payoutMethodId': methodId,
      'amount': amount,
      'currency': currency,
    }));
    DataBus.changed(DataTopic.wallet);
  }

  Future<List<PayoutRequestRow>> payoutRequests({int page = 1, int limit = 50}) async {
    final res = await _api.get('/wallet/payout-requests',
        queryParameters: {'page': page, 'limit': limit});
    final data = unwrapData(res);
    final raw = data is Map ? (data['list'] ?? []) : (data ?? []);
    return (raw as List)
        .whereType<Map>()
        .map((e) => PayoutRequestRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---- Stripe Connect (website: top-up.component payout accounts) ----

  /// Preferred onboarding path: `/stripe-connect/onboard` creates the
  /// Express account if needed and returns the hosted onboarding URL.
  Future<String?> stripeOnboardingLink() async {
    final data = unwrapData(await _api.post('/stripe-connect/onboard'));
    return data is Map
        ? (data['onboardingUrl'] ?? data['url'] ?? data['link'])?.toString()
        : null;
  }

  Future<StripeConnectStatus> stripeStatus() async {
    final data = unwrapData(await _api.get('/stripe-connect/status'));
    return StripeConnectStatus.fromJson(
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
  }

  /// Express dashboard login link for already-active accounts.
  Future<String?> stripeDashboardLink() async {
    final data = unwrapData(await _api.get('/stripe-connect/dashboard-link'));
    return data is Map
        ? (data['url'] ?? data['dashboardUrl'] ?? data['link'])?.toString()
        : null;
  }

  /// Marks the Stripe Connect account as a payout method once onboarded.
  Future<String?> linkStripe() async {
    final data = unwrapData(await _api.post('/wallet/payout-methods/stripe/link'));
    return data is Map ? (data['url'] ?? data['onboardingUrl'])?.toString() : null;
  }

  Future<void> addPaypal(String email) async {
    unwrapData(await _api.post('/wallet/payout-methods/paypal', data: {'email': email}));
  }

  /// Wise bank transfer — field names match the API contract exactly
  /// (snake_case, IBAN + SWIFT), same as the website's Wise form.
  Future<void> addWise({
    required String accountHolderName,
    required String accountNumber,
    required String swiftBic,
    required String beneficiaryCountry,
    required String bankAddress,
  }) async {
    unwrapData(await _api.post('/wallet/payout-methods/wise', data: {
      'account_holder_name': accountHolderName,
      'account_number': accountNumber,
      'swift_bic': swiftBic,
      'beneficiary_country': beneficiaryCountry,
      'bank_address': bankAddress,
    }));
  }

  Future<void> setDefaultMethod(int id) async {
    unwrapData(await _api.patch('/wallet/payout-methods/$id', data: {'is_default': true}));
    DataBus.changed(DataTopic.wallet);
  }

  Future<void> removeMethod(int id) async {
    unwrapData(await _api.delete('/wallet/payout-methods/$id'));
    DataBus.changed(DataTopic.wallet);
  }
}
