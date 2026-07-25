import 'package:get/get.dart';
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';

class KycStatus {
  final String status; // not_started | pending | approved | declined
  final bool verified;

  const KycStatus({this.status = 'not_started', this.verified = false});

  factory KycStatus.fromJson(Map<String, dynamic> json) => KycStatus(
        status: json['status'] ?? 'not_started',
        verified: json['verified'] ?? false,
      );

  // what to tell the user when they're blocked
  String get message => switch (status) {
        'pending' => 'Your identity check is still being reviewed.',
        'declined' => 'Your identity check was declined. Please try again.',
        _ => 'Verify your identity before you can create a deal.',
      };
}

class KycRepository {
  final _api = Get.find<ApiService>();

  Future<KycStatus> status() async {
    final res = await _api.get('/kyc/status');
    return KycStatus.fromJson(Map<String, dynamic>.from(unwrapData(res)));
  }

  // returns the hosted verification URL to open in a webview/browser
  Future<String?> startVerification() async {
    final res = await _api.post('/kyc/verify');
    final data = unwrapData(res);
    return data is Map ? data['verificationUrl'] : null;
  }
}
