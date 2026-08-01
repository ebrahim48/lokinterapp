// Badge precedence from the API doc: an active paid subscription shows the
// recommended badge; an approved transporter without one shows the plain badge.
import 'package:flutter_task/features/auth/data/models/auth_user.dart';
import 'package:flutter_task/features/posts/data/models/post_model.dart';
import 'package:flutter_test/flutter_test.dart';

AuthUser user(Map<String, dynamic> extra) => AuthUser.fromJson({
      'id': 1,
      'fullName': 'Triple R Logistics',
      'email': 'rrr@gmail.com',
      ...extra,
    });

void main() {
  group('AuthUser badges', () {
    test('subscribed transporter gets the recommended badge', () {
      final u = user({
        'isTransporter': true,
        'transporterVerificationStatus': 'approved',
        'isFeaturedTransporter': true,
        'transporterVisibilityStatus': 'active',
      });
      expect(u.showRecommendedBadge, isTrue);
      expect(u.showTransporterBadge, isTrue); // recommended wins at render time
    });

    test('expired subscription falls back to the plain badge', () {
      final u = user({
        'isTransporter': true,
        'transporterVerificationStatus': 'approved',
        'isFeaturedTransporter': true,
        'transporterVisibilityStatus': 'expired',
      });
      expect(u.showRecommendedBadge, isFalse);
      expect(u.showTransporterBadge, isTrue);
    });

    test('a pending application shows no badge', () {
      final u = user({
        'isTransporter': true,
        'transporterVerificationStatus': 'pending',
      });
      expect(u.showRecommendedBadge, isFalse);
      expect(u.showTransporterBadge, isFalse);
      expect(u.transporterPending, isTrue);
    });

    test('a normal user has no transporter state', () {
      final u = user({});
      expect(u.isTransporter, isFalse);
      expect(u.showTransporterBadge, isFalse);
    });
  });

  group('PostUser badges on cards', () {
    test('subscribed transporter is flagged recommended', () {
      final p = PostUser.fromJson({
        'id': 12,
        'name': 'Triple R',
        'isTransporter': true,
        'transporterVerificationStatus': 'approved',
        'isFeaturedTransporter': true,
        'transporterVisibilityStatus': 'active',
      });
      expect(p.isTransporter, isTrue);
      expect(p.isRecommendedTransporter, isTrue);
    });

    test('an unapproved transporter shows no chip', () {
      final p = PostUser.fromJson({
        'id': 13,
        'name': 'Pending Co',
        'isTransporter': true,
        'transporterVerificationStatus': 'pending',
      });
      expect(p.isTransporter, isFalse);
      expect(p.isRecommendedTransporter, isFalse);
    });
  });
}
