import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';

/// "Increase Visibility to Senders": travelers apply for free once they meet
/// the conditions, transporters pay a monthly subscription for premium
/// placement, and normal users can request the transporter upgrade.
class VisibilityRepository {
  final _api = Get.find<ApiService>();

  /// Free recommended-traveler application. The server re-checks eligibility
  /// (3 completed deliveries, no disputes, ID + phone verified).
  /// Returns `{status, completedCount, isKycVerified, averageRating,
  /// isAutoApproved}` — the server auto-approves when the conditions hold.
  Future<Map<String, dynamic>> applyTraveler() async {
    final data = unwrapData(await _api.post('/visibility/apply-traveler'));
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// Recommended-transporter subscription — $22.99 for 30 days.
  ///
  /// Returns whatever the endpoint gives back. When it includes a
  /// `clientSecret` the caller runs the same card step escrow uses; when it
  /// doesn't, the server settled the payment itself and the subscription is
  /// already active (`{isFeatured, featuredUntil, visibilityStatus, ...}`).
  Future<Map<String, dynamic>> subscribeTransporter({
    double amount = 22.99,
    String provider = 'Stripe',
    int durationDays = 30,
  }) async {
    final res = await _api.post('/visibility/transporter/subscribe', data: {
      'amount': amount,
      'provider': provider,
      'durationDays': durationDays,
    });
    final data = unwrapData(res);
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// Tells the backend the card cleared, mirroring escrow's confirm step.
  /// Safe to skip when the subscription was settled server-side.
  Future<void> confirmTransporterSubscription(String paymentIntentId) async {
    unwrapData(await _api.post('/visibility/transporter/confirm-subscription',
        data: {'paymentIntentId': paymentIntentId}));
  }

  /// Upgrade an existing sender/traveler account to a transporter. Goes to
  /// `pending` for admin review; the documents are required.
  Future<void> requestTransporterVerification({
    required String legalName,
    required String address,
    required List<String> operatingCountries,
    required String transportLicensePath,
    required String legalDocumentPath,
  }) async {
    final form = FormData.fromMap({
      'legalName': legalName,
      'address': address,
      'transportLicense': await MultipartFile.fromFile(
        transportLicensePath,
        filename: transportLicensePath.split('/').last,
      ),
      'legalDocument': await MultipartFile.fromFile(
        legalDocumentPath,
        filename: legalDocumentPath.split('/').last,
      ),
    });
    // repeated keys, so the API sees operatingCountries[] as a list
    for (final iso in operatingCountries) {
      form.fields.add(MapEntry('operatingCountries[]', iso));
    }
    unwrapData(await _api.post('/transporters/request-verification', data: form));
  }
}
