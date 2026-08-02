// The four recommended-traveler conditions come straight from /auth/user.
// Uses the exact payload the API returns.
import 'package:flutter_task/features/auth/data/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

AuthUser fromApi(Map<String, dynamic> extra) => AuthUser.fromJson({
      'id': 3,
      'fullName': 'Test User',
      'email': 'test@gmail.com',
      ...extra,
    });

void main() {
  test('the documented payload makes the user eligible', () {
    final u = fromApi({
      'phoneVerified': true,
      'identityVerified': true,
      'kycStatus': 'approved',
      'isTransporter': true,
      'successfulDeliveriesCount': 3,
      'disputesOnCompletedDeliveriesCount': 0,
      'hasNoDisputesOnCompletedDeliveries': true,
    });
    expect(u.hasThreeDeliveries, isTrue);
    expect(u.hasNoDisputes, isTrue);
    expect(u.identityVerified, isTrue);
    expect(u.phoneVerified, isTrue);
    expect(u.canApplyRecommendedTraveler, isTrue);
  });

  test('under three deliveries leaves the no-disputes row unchecked too', () {
    final u = fromApi({
      'phoneVerified': true,
      'identityVerified': true,
      'successfulDeliveriesCount': 2,
      'hasNoDisputesOnCompletedDeliveries': true,
    });
    expect(u.hasThreeDeliveries, isFalse);
    expect(u.hasNoDisputes, isFalse, reason: 'depends on the delivery count');
    expect(u.canApplyRecommendedTraveler, isFalse);
  });

  test('a dispute blocks eligibility even with enough deliveries', () {
    final u = fromApi({
      'phoneVerified': true,
      'identityVerified': true,
      'successfulDeliveriesCount': 5,
      'disputesOnCompletedDeliveriesCount': 1,
      'hasNoDisputesOnCompletedDeliveries': false,
    });
    expect(u.hasThreeDeliveries, isTrue);
    expect(u.hasNoDisputes, isFalse);
    expect(u.canApplyRecommendedTraveler, isFalse);
  });

  test('each remaining condition is required on its own', () {
    const base = {
      'successfulDeliveriesCount': 3,
      'hasNoDisputesOnCompletedDeliveries': true,
      'identityVerified': true,
      'phoneVerified': true,
    };
    expect(fromApi({...base, 'identityVerified': false}).canApplyRecommendedTraveler, isFalse);
    expect(fromApi({...base, 'phoneVerified': false}).canApplyRecommendedTraveler, isFalse);
  });

  test('phoneVerified falls back to the timestamp when the flag is absent', () {
    final u = fromApi({'phoneVerifiedAt': '2026-07-20T05:34:59.000000Z'});
    expect(u.phoneVerified, isTrue);
    expect(fromApi({}).phoneVerified, isFalse);
  });
}
