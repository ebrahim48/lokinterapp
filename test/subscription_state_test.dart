// The subscribe button is driven by the `subscription` object /auth/user
// returns — null while unsubscribed, {status:true,...} while a plan runs.
import 'package:flutter_task/features/auth/data/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

AuthUser u(Map<String, dynamic> extra) => AuthUser.fromJson({
      'id': 3,
      'fullName': 'Test User',
      'email': 'test@gmail.com',
      ...extra,
    });

void main() {
  test('null subscription leaves the button enabled', () {
    final user = u({'subscription': null});
    expect(user.hasActiveSubscription, isFalse);
    expect(user.subscriptionEndsOn, isNull);
  });

  test('an active plan disables it and exposes the end date', () {
    final user = u({
      'subscription': {
        'status': true,
        'planTitle': 'Recommended Transporter',
        'startDate': '2026-08-01T10:00:00.000000Z',
        'endDate': '2026-08-31T10:00:00.000000Z',
      }
    });
    expect(user.hasActiveSubscription, isTrue);
    expect(user.subscriptionEndsOn, '2026-08-31');
  });

  test('a space-separated date is handled too', () {
    final user = u({
      'subscription': {'status': true, 'endDate': '2026-08-31 10:00:00'}
    });
    expect(user.subscriptionEndsOn, '2026-08-31');
  });

  test('an expired plan (status false) does not count as subscribed', () {
    final user = u({
      'subscription': {'status': false, 'endDate': '2026-01-01 10:00:00'}
    });
    expect(user.hasActiveSubscription, isFalse);
  });
}
