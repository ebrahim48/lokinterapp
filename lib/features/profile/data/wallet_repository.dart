import 'package:get/get.dart';
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/data_bus.dart';

// The wallet API is loose with types (ids as strings, booleans as 0/1). A hard
// cast here throws a TypeError the screens can't recover from, so read
// everything leniently.
int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

bool _bool(dynamic v) =>
    v == true || v == 1 || '$v'.toLowerCase() == 'true' || '$v' == '1';

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
  /// Frozen because a dispute was opened on the deal — shown under "On hold"
  /// as waiting for the dispute resolution, never as a pending earning.
  final bool onHold;

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
    this.onHold = false,
  });

  factory WalletEarning.fromJson(Map<String, dynamic> e) => WalletEarning(
        dealId: _int(e['dealId']),
        dealRef: '${e['dealRef'] ?? ''}',
        dealStatus: '${e['dealStatus'] ?? ''}',
        amount: double.tryParse('${e['amount'] ?? 0}') ?? 0,
        profit: double.tryParse('${e['profit'] ?? 0}') ?? 0,
        itemCost: double.tryParse('${e['itemCost'] ?? 0}') ?? 0,
        statusLabel: '${e['statusLabel'] ?? e['reason'] ?? ''}',
        releaseAt: DateTime.tryParse('${e['releaseAt'] ?? ''}'),
        countdownSeconds: (e['countdownSeconds'] ?? e['disputeCountdownSeconds']) is num
            ? ((e['countdownSeconds'] ?? e['disputeCountdownSeconds']) as num).toInt()
            : null,
        onHold: _bool(e['fundsLockedForDispute']) ||
            _bool(e['isOnHold']) ||
            '${e['status'] ?? ''}'.toUpperCase() == 'ON_HOLD' ||
            const ['DISPUTED', 'DISPUTES', 'DISPUTE']
                .contains('${e['dealStatus'] ?? ''}'.toUpperCase()),
      );

  /// Why the money is not withdrawable yet, in the app language for holds.
  String get reasonLabel =>
      onHold ? 'waiting_for_dispute_resolution'.tr : statusLabel;

  /// "5h 20m left" while the hold is still counting down.
  String? get countdownText {
    final s = countdownSeconds;
    if (s == null || s <= 0) return null;
    final h = s ~/ 3600, m = (s % 3600) ~/ 60;
    return 'time_left'.trParams({'time': h > 0 ? '${h}h ${m}m' : '${m}m'});
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
        dealId: _int(e['dealId']),
        dealRef: '${e['dealRef'] ?? ''}',
        amountCharged: double.tryParse('${e['amountCharged'] ?? 0}') ?? 0,
        statusLabel: '${e['statusLabel'] ?? ''}',
        reason: '${e['reason'] ?? ''}',
        status: '${e['status'] ?? ''}',
      );
}

class WalletData {
  /// Withdrawable balance — bind UI "Available" to THIS, NOT to [available].
  /// [available] is Stripe Connect's payout-ready balance and is often 0.
  final double walletBalance;
  /// Alias for [walletBalance] (some older endpoints use `withdrawable`).
  final double withdrawable;
  /// Stripe Connect payout-ready balance — NOT the user-visible "Available".
  final double available;
  /// Earnings still awaiting release (dispute window, escrow, etc.).
  final double pendingEarnings;
  /// Funds held temporarily (active disputes, guarantees).
  final double onHold;
  /// Payout already requested but not yet processed.
  final double pendingWithdrawal;
  final double totalPending;
  final double lifetimeEarnings;
  final String currency;
  final bool hasStripeConnect;
  /// Everything still owed to the traveler, each with why it is held.
  final List<WalletEarning> potential;
  /// Earnings frozen by an open dispute (moved out of pending).
  final List<WalletEarning> onHoldEarnings;
  final List<WalletDispute> disputes;

  const WalletData({
    this.walletBalance = 0,
    this.withdrawable = 0,
    this.available = 0,
    this.pendingEarnings = 0,
    this.onHold = 0,
    this.pendingWithdrawal = 0,
    this.totalPending = 0,
    this.lifetimeEarnings = 0,
    this.currency = 'USD',
    this.hasStripeConnect = false,
    this.potential = const [],
    this.onHoldEarnings = const [],
    this.disputes = const [],
  });

  /// The value to show in the "Available" slot in the UI.
  double get displayBalance => walletBalance > 0 ? walletBalance : withdrawable;

  factory WalletData.fromJson(Map<String, dynamic> json) {
    List<WalletEarning> earnings(dynamic raw) => [
          for (final e in (raw is List ? raw : const []).whereType<Map>())
            WalletEarning.fromJson(Map<String, dynamic>.from(e)),
        ];
    // earnings frozen by a dispute: the dedicated list, plus anything the
    // pending list still flags as locked
    final pending = earnings(json['potentialEarningsList'] ??
        json['pendingDealsList'] ??
        json['recentEarnings']);
    final held = earnings(json['onHoldDeals'] ?? json['onHoldList']);
    final heldIds = {for (final e in held) e.dealId};
    for (final e in pending) {
      if (e.onHold && heldIds.add(e.dealId)) {
        held.add(WalletEarning(
          dealId: e.dealId,
          dealRef: e.dealRef,
          dealStatus: e.dealStatus,
          amount: e.amount,
          profit: e.profit,
          itemCost: e.itemCost,
          statusLabel: e.statusLabel,
          onHold: true,
        ));
      }
    }
    // the API has sent the hold under three names; a 0 under the first one
    // must not hide a real amount under another
    final heldTotal = [
      _d(json['onHold']),
      _d(json['disputeHoldAmount']),
      _d(json['onHoldDispute']),
    ].fold<double>(0, (a, b) => b > a ? b : a);
    final heldListTotal = held.fold<double>(0, (a, e) => a + e.amount);

    return WalletData(
      // primary keys per spec
      walletBalance: _d(json['walletBalance']),
      withdrawable: _d(json['withdrawable']),
      // kept for reference but do NOT show this as "Available"
      available: _d(json['available']),
      pendingEarnings: _d(json['pendingEarnings']),
      onHold: heldTotal > 0 ? heldTotal : heldListTotal,
      pendingWithdrawal: _d(json['pendingWithdrawal']),
      totalPending: _d(json['totalPending']),
      lifetimeEarnings: _d(json['lifetimeEarnings']),
      currency: '${json['currency'] ?? 'USD'}',
      hasStripeConnect: _bool(json['hasStripeConnect']),
      // held earnings are listed under "On hold", not twice
      potential: [for (final e in pending) if (!heldIds.contains(e.dealId)) e],
      onHoldEarnings: held,
      disputes: [
        for (final e in (json['disputeHistory'] as List? ?? const [])
            .whereType<Map>())
          WalletDispute.fromJson(Map<String, dynamic>.from(e)),
      ],
    );
  }

  static double _d(dynamic v) =>
      v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
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
        id: _int(json['id']),
        // the API names it `method` ("wise"); older payloads used type/provider
        type: (json['type'] ?? json['provider'] ?? json['method'] ?? '')
            .toString()
            .toUpperCase(),
        isDefault: _bool(json['isDefault'] ?? json['is_default']),
        label: [
          json['displayLabel'] ?? json['type'] ?? json['provider'] ?? json['method'] ??
              'account'.tr,
          json['summary'] ??
              (json['last4'] != null ? '•••• ${json['last4']}' : (json['email'] ?? '')),
        ].where((s) => s.toString().isNotEmpty).join(' · '),
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
  /// Raw status (completed / pending / ...) when no label is sent.
  final String status;
  final String reason;
  final int dealId;
  final String dealRef;
  /// Human-readable deal ID e.g. "#DL-123" — show THIS, not [dealRef].
  final String dealDisplayId;
  /// Human-readable description — show THIS instead of any encrypted ref.
  final String displayDescription;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    this.createdAt,
    this.statusLabel = '',
    this.status = '',
    this.reason = '',
    this.dealId = 0,
    this.dealRef = '',
    this.dealDisplayId = '',
    this.displayDescription = '',
  });

  bool get isCredit =>
      type == 'credit' || type == 'refund' || type == 'release' || type == 'external_credit';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: _int(json['id']),
        type: (json['type'] ?? '').toString(),
        amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
        balanceAfter: double.tryParse('${json['balanceAfter'] ?? json['balance_after'] ?? 0}') ?? 0,
        description: (json['description'] ?? '').toString(),
        createdAt: DateTime.tryParse(
            '${json['dateTime'] ?? json['createdAt'] ?? json['created_at'] ?? ''}'),
        statusLabel: '${json['statusLabel'] ?? ''}',
        status: '${json['status'] ?? ''}',
        reason: '${json['reason'] ?? ''}',
        dealId: _int(json['dealId']),
        dealRef: '${json['dealRef'] ?? ''}',
        dealDisplayId: '${json['dealDisplayId'] ?? ''}',
        displayDescription: '${json['displayDescription'] ?? json['description'] ?? ''}',
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
        id: _int(json['id']),
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
  /// When false the fee is variable (e.g. Wise) — show [message] instead of
  /// "Fee: 0 USD". Never show "Fee: 0" when this is false.
  final bool showFeeAmount;
  /// Human-readable note returned by the backend when [showFeeAmount] is false.
  final String? message;

  const PayoutQuote({
    required this.amount,
    required this.feeAmount,
    required this.netAmount,
    required this.currency,
    this.showFeeAmount = true,
    this.message,
  });

  factory PayoutQuote.fromJson(Map<String, dynamic> json) => PayoutQuote(
        amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
        feeAmount: double.tryParse('${json['feeAmount'] ?? json['fee_amount'] ?? 0}') ?? 0,
        netAmount: double.tryParse('${json['netAmount'] ?? json['net_amount'] ?? 0}') ?? 0,
        currency: (json['currency'] ?? 'USD').toString(),
        // either flag may say the fee is unknown in advance
        showFeeAmount: (json['showFeeAmount'] ?? json['feeKnown']) == null ||
            _bool(json['showFeeAmount'] ?? json['feeKnown']),
        message: json['message']?.toString(),
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
        connected: _bool(json['connected']),
        status: (json['status'] ?? 'none').toString(),
        canReceivePayments: _bool(json['canReceivePayments']),
      );
}

class WalletRepository {
  final _api = Get.find<ApiService>();

  /// Server switch for PayPal payouts (`paypalEnabled` on payout-methods).
  /// Off unless the API turns it on — PayPal is not used for now.
  static bool paypalEnabled = false;

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
    // Always read data.list — other shapes (bare array, Map without list) are
    // defensive fallbacks for older payloads.
    final List raw;
    if (data is Map) {
      final list = data['list'];
      if (list is List) {
        raw = list;
      } else {
        // list may be null or absent when retryable:true — treat as empty
        raw = const [];
      }
    } else if (data is List) {
      raw = data;
    } else {
      raw = const [];
    }
    paypalEnabled = data is Map && _bool(data['paypalEnabled']);
    return raw
        .whereType<Map>()
        .map((e) => PayoutMethod.fromJson(Map<String, dynamic>.from(e)))
        // a PayPal method saved earlier stays hidden while PayPal is off
        .where((m) => paypalEnabled || m.type != 'PAYPAL')
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

  Future<void> requestPayout(int methodId, double amount, [String? currency]) async {
    unwrapData(await _api.post('/wallet/payout-requests', data: {
      'payoutMethodId': methodId,
      'amount': amount,
      if (currency != null) 'currency': currency,
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
