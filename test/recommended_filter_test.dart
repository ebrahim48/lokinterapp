import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_task/features/posts/data/models/post_model.dart';

Map<String, dynamic> _trip({
  String beforeDate = '2099-01-01 10:00',
  String? createdAt,
  Map<String, dynamic> user = const {},
}) =>
    {
      'id': 1,
      'type': 'TRIP',
      'location': 'INTERNATIONAL',
      'beforeDate': beforeDate,
      'createdAt': ?createdAt,
      'user': {'id': 9, 'name': 'T', ...user},
    };

void main() {
  group('visibilityState', () {
    test('no visibility field says nothing', () {
      expect(visibilityState({'id': 1}), isNull);
    });
    test('active status or flag is on', () {
      expect(visibilityState({'visibilityStatus': 'active'}), isTrue);
      expect(visibilityState({'isFeaturedTransporter': true}), isTrue);
    });
    test('expired status or false flag is off', () {
      expect(visibilityState({'visibilityStatus': 'expired'}), isFalse);
      expect(visibilityState({'visibilityActive': false}), isFalse);
    });
    test('an admin switch-off beats a stale featured flag', () {
      expect(
          visibilityState({'isFeaturedTransporter': true, 'visibilityEnabled': false}),
          isFalse);
    });
  });

  group('showInRecommended', () {
    test('an "Available upon request" trip from yesterday is dropped', () {
      final y = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final post = Post.fromJson(_trip(
          beforeDate: 'Available upon request', createdAt: y.toIso8601String()));
      expect(post.showInRecommended, isFalse);
    });
    test('an "Available upon request" trip from today stays', () {
      final post = Post.fromJson(_trip(
          beforeDate: 'Available upon request',
          createdAt: DateTime.now().toUtc().toIso8601String()));
      expect(post.showInRecommended, isTrue);
    });
    test('a traveler whose visibility is off is dropped', () {
      final post = Post.fromJson(_trip(user: {'visibilityStatus': 'disabled'}));
      expect(post.showInRecommended, isFalse);
    });
  });
}
