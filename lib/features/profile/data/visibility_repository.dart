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

  /// Returns the current transporter visibility status from the server.
  /// Keys include: `visibilityStatus`, `featuredUntil`, `isFeatured`, etc.
  Future<Map<String, dynamic>> transporterStatus() async {
    final data = unwrapData(await _api.get('/visibility/transporter/status'));
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// Recommended-transporter subscription — $23.99 for 30 days.
  ///
  /// Returns `{clientSecret, paymentIntentId, alreadyActive, requiresPayment}`.
  /// When `alreadyActive` is true the subscription is already running.
  /// When `requiresPayment` is false the server settled without Stripe.
  /// Otherwise open the Stripe PaymentSheet with `clientSecret`.
  Future<Map<String, dynamic>> subscribeTransporter() async {
    final res = await _api.post('/visibility/transporter/subscribe');
    final data = unwrapData(res);
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// Confirms that Stripe has charged the card for the transporter subscription.
  /// Only call this after the PaymentSheet succeeds (or when requiresPayment is false).
  Future<void> confirmTransporterPayment(String paymentIntentId) async {
    unwrapData(await _api.post('/visibility/transporter/confirm-payment',
        data: {'paymentIntentId': paymentIntentId}));
  }

  /// Backward-compat alias — prefer [confirmTransporterPayment].
  Future<void> confirmTransporterSubscription(String paymentIntentId) =>
      confirmTransporterPayment(paymentIntentId);

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
      'businessAddress': address,
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
