// Parsed straight from the two /auth/user responses supplied by the API team,
// so the verified/unverified split can never drift.
import 'package:flutter_task/features/auth/data/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---- user 1: fully verified, subscribed transporter ----
  final verified = AuthUser.fromJson({
    'id': 1,
    'firstName': 'Sushil',
    'lastName': 'Hemrom',
    'fullName': 'Sushil Hemrom',
    'phone': '5512345678',
    'intlPhone': null,
    'email': 'sushil500530@gmail.com',
    'phoneVerifiedAt': '2026-07-20T05:34:59.000000Z',
    'phoneVerified': true,
    'country': 'BD',
    'isTransporter': true,
    'lang': 'en',
    'subscription': {
      'status': true,
      'planTitle': 'Recommended Transporter',
      'startDate': '2026-08-02T09:15:27.000000Z',
      'endDate': '2026-09-02T09:15:27.000000Z',
    },
    'kycStatus': 'approved',
    'kycVerifiedAt': '2026-07-20T05:34:59.000000Z',
    'identityVerified': true,
    'successfulDeliveriesCount': 3,
    'disputesOnCompletedDeliveriesCount': 0,
    'hasNoDisputesOnCompletedDeliveries': true,
  });

  // ---- user 12: phone NOT verified, no kyc, no subscription ----
  final unverified = AuthUser.fromJson({
    'id': 12,
    'fullName': 'triple R gy',
    'phone': '+2442858828', // present but unverified — must not imply verified
    'email': 'rrr@gmail.com',
    'phoneVerifiedAt': null,
    'phoneVerified': false,
    'country': 'AO',
    'isTransporter': true,
    'legalName': 'rrr',
    'address': 'yyy',
    'operatingCountries': [
      'AL', 'AT', 'AZ', 'DZ', 'AD', 'AF', 'BH', 'BD', 'BY', 'BE', 'BR', 'CA', 'BG'
    ],
    'subscription': null,
    'kycStatus': null,
    'kycVerifiedAt': null,
    'identityVerified': false,
    'successfulDeliveriesCount': 0,
    'hasNoDisputesOnCompletedDeliveries': true,
  });

  test('user 1 is phone verified', () {
    expect(verified.phoneVerified, isTrue);
    expect(verified.identityVerified, isTrue);
  });

  test('user 12 is NOT phone verified even though a phone is set', () {
    expect(unverified.phone, '+2442858828');
    expect(unverified.phoneVerified, isFalse,
        reason: 'a stored number is not a verified number');
    expect(unverified.identityVerified, isFalse);
  });

  test('an explicit false is never overridden by the timestamp fallback', () {
    final u = AuthUser.fromJson({
      'id': 3,
      'fullName': 'x',
      'email': 'x@y.z',
      'phoneVerified': false,
      'phoneVerifiedAt': null,
    });
    expect(u.phoneVerified, isFalse);
  });

  test('an older payload without the flag falls back to the timestamp', () {
    final u = AuthUser.fromJson({
      'id': 4,
      'fullName': 'x',
      'email': 'x@y.z',
      'phoneVerifiedAt': '2026-07-20T05:34:59.000000Z',
    });
    expect(u.phoneVerified, isTrue);
  });

  test('subscription and eligibility follow the same payloads', () {
    expect(verified.hasActiveSubscription, isTrue);
    expect(verified.subscriptionEndsOn, '2026-09-02');
    expect(verified.canApplyRecommendedTraveler, isTrue);

    expect(unverified.hasActiveSubscription, isFalse);
    expect(unverified.canApplyRecommendedTraveler, isFalse);
  });

  test('isTransporter alone counts as an application already on file', () {
    // user 12 has isTransporter true but no status field at all
    expect(unverified.isTransporter, isTrue);
    expect(unverified.transporterApplied, isTrue,
        reason: 'must not be asked to apply again');
    expect(unverified.showTransporterBadge, isFalse,
        reason: 'no approved status, so no badge yet');
  });

  test('an ordinary account is still offered the application', () {
    final plain = AuthUser.fromJson(
        {'id': 5, 'fullName': 'x', 'email': 'x@y.z', 'isTransporter': false});
    expect(plain.transporterApplied, isFalse);
  });

  test('submitted business details are kept', () {
    expect(unverified.legalName, 'rrr');
    expect(unverified.address, 'yyy');
    expect(unverified.operatingCountries, contains('AL'));
    expect(unverified.operatingCountries.length, 13);
  });

  test('the verified user survives a cache round-trip', () {
    final again = AuthUser.fromJson(verified.toJson());
    expect(again.phoneVerified, isTrue);
    expect(again.identityVerified, isTrue);
    expect(again.hasActiveSubscription, isTrue);
  });
}
