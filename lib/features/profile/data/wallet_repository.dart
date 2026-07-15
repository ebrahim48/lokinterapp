import 'package:get/get.dart';
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';

class WalletEarning {
  final int dealId;
  final double amount;
  final bool credit;
  final String label;

  const WalletEarning({
    required this.dealId,
    required this.amount,
    this.credit = true,
    required this.label,
  });
}

class WalletData {
  final double available;
  final double totalPending;
  final double lifetimeEarnings;
  final String currency;
  final bool hasStripeConnect;
  final List<WalletEarning> recent;

  const WalletData({
    this.available = 0,
    this.totalPending = 0,
    this.lifetimeEarnings = 0,
    this.currency = 'USD',
    this.hasStripeConnect = false,
    this.recent = const [],
  });

  factory WalletData.fromJson(Map<String, dynamic> json) => WalletData(
        available: ((json['available'] ?? 0) as num).toDouble(),
        totalPending: ((json['totalPending'] ?? 0) as num).toDouble(),
        lifetimeEarnings: ((json['lifetimeEarnings'] ?? 0) as num).toDouble(),
        currency: json['currency'] ?? 'USD',
        hasStripeConnect: json['hasStripeConnect'] ?? false,
        recent: [
          for (final e in (json['recentEarnings'] as List? ?? []).whereType<Map>())
            WalletEarning(
              dealId: e['dealId'] ?? 0,
              amount: ((e['amount'] ?? 0) as num).toDouble(),
              label: 'Delivery payout — deal #${e['dealId']}',
            ),
        ],
      );
}

class PayoutMethod {
  final int id;
  final String label;

  const PayoutMethod({required this.id, required this.label});

  factory PayoutMethod.fromJson(Map<String, dynamic> json) => PayoutMethod(
        id: json['id'] ?? 0,
        label: [
          json['type'] ?? json['provider'] ?? 'Account',
          json['last4'] != null ? '•••• ${json['last4']}' : (json['email'] ?? ''),
        ].where((s) => s.toString().isNotEmpty).join(' '),
      );
}

class WalletRepository {
  final _api = Get.find<ApiService>();

  Future<WalletData> dashboard() async {
    final res = await _api.get('/wallet/');
    return WalletData.fromJson(Map<String, dynamic>.from(unwrapData(res)));
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

  Future<void> requestPayout(int methodId, double amount, String currency) async {
    unwrapData(await _api.post('/wallet/payout-requests', data: {
      'payoutMethodId': methodId,
      'amount': amount,
      'currency': currency,
    }));
  }
}
