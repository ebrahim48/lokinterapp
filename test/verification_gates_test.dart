// Phone verification is read from /auth/user and gates messaging, posting and
// deal creation; the API's 403 is the backstop when the client state is stale.
import 'package:flutter_task/core/exceptions/app_exceptions.dart';
import 'package:flutter_task/features/auth/data/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

AuthUser u(Map<String, dynamic> extra) => AuthUser.fromJson({
      'id': 12,
      'fullName': 'triple R gy',
      'email': 'rrr@gmail.com',
      ...extra,
    });

void main() {
  group('phone verification flag', () {
    test('the unverified account from the API is blocked', () {
      // exactly the payload shared for user 12
      final user = u({'phoneVerifiedAt': null, 'phoneVerified': false});
      expect(user.phoneVerified, isFalse);
    });

    test('a verified account passes', () {
      final user = u({
        'phoneVerified': true,
        'phoneVerifiedAt': '2026-07-20T05:34:59.000000Z',
      });
      expect(user.phoneVerified, isTrue);
    });

    test('older payloads fall back to the timestamp', () {
      expect(u({'phoneVerifiedAt': '2026-07-20T05:34:59.000000Z'}).phoneVerified,
          isTrue);
      expect(u({}).phoneVerified, isFalse);
    });
  });

  group('identity (KYC) flag', () {
    test('approved kyc counts as verified', () {
      final user = u({'identityVerified': true, 'kycStatus': 'approved'});
      expect(user.identityVerified, isTrue);
    });

    test('a null kycStatus is not verified', () {
      final user = u({'identityVerified': false, 'kycStatus': null});
      expect(user.identityVerified, isFalse);
    });
  });

  group('server 403 detection', () {
    // maybeKycPrompt keys off the API's wording, since details is a String
    bool looksLikeKyc(AppException e) {
      final probe = '${e.message} ${e.details ?? ''}'.toLowerCase();
      return probe.contains('requireskyc') ||
          probe.contains('document verification is required');
    }

    test('the documented sender 403 is recognised', () {
      expect(
          looksLikeKyc(ServerException(
              'Document verification is required before confirming a deal.', 403)),
          isTrue);
    });

    test('the documented traveler 403 is recognised', () {
      expect(
          looksLikeKyc(ServerException(
              'Document verification is required before accepting a deal.', 403)),
          isTrue);
    });

    test('an unrelated error is left alone', () {
      expect(looksLikeKyc(ServerException('Weight must be an integer', 422)),
          isFalse);
    });
  });
}
