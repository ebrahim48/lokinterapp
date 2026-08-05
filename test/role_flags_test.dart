import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_task/features/chat/data/chat_model.dart';
import 'package:flutter_task/features/deals/data/deal_model.dart';
import 'package:flutter_task/features/posts/data/models/post_model.dart';

// The API now states who created a post and what role I hold in the deal.
// Those flags win; the old inference stays as the fallback for older payloads.
void main() {
  group('deal roles', () {
    test('boolean flags are taken at face value', () {
      final d = Deal.fromJson({'id': 1, 'isSender': true, 'isTraveler': false});
      expect(d.isSender, isTrue);
      expect(d.isTraveler, isFalse);
    });

    test('userRole alone is enough', () {
      final t = Deal.fromJson({'id': 1, 'userRole': 'TRAVELER'});
      expect(t.isTraveler, isTrue);
      expect(t.isSender, isFalse);

      final s = Deal.fromJson({'id': 1, 'userRole': 'SENDER'});
      expect(s.isSender, isTrue);
      expect(s.isTraveler, isFalse);
    });

    test('list rows carry the role and the post type', () {
      final d = Deal.fromListJson({
        'id': 7,
        'postType': 'TRIP',
        'userRole': 'SENDER',
        'status': 'ACCEPTED',
      });
      expect(d.type, PostType.trip);
      expect(d.isSender, isTrue);
    });

    test('a payload without any role flag reads as neither', () {
      final d = Deal.fromJson({'id': 1});
      expect(d.isSender, isFalse);
      expect(d.isTraveler, isFalse);
    });
  });

  group('chat post roles', () {
    // a DELIVER post owned by someone else would infer "not sender"; the
    // explicit role overrules that
    test('userRole overrules the post-type inference', () {
      final ctx = ChatPostContext.fromJson({
        'id': 3,
        'type': 'DELIVER',
        'user': {'id': 99},
        'userRole': 'SENDER',
      })!;
      expect(ctx.isSender(5), isTrue);
    });

    test('without it, ownership still decides', () {
      final ctx = ChatPostContext.fromJson({
        'id': 3,
        'type': 'DELIVER',
        'user': {'id': 5},
      })!;
      expect(ctx.isSender(5), isTrue);
      expect(ctx.isSender(9), isFalse);
    });
  });

  group('post ownership', () {
    test('isPostCreator wins over the id comparison', () {
      final p = Post.fromJson({
        'id': 1,
        'type': 'TRIP',
        'weight': 5,
        'user': {'id': 42},
        'isPostCreator': true,
      });
      expect(p.mine(7), isTrue);
    });

    test('falls back to comparing ids', () {
      final p = Post.fromJson({
        'id': 1,
        'type': 'TRIP',
        'weight': 5,
        'user': {'id': 42},
      });
      expect(p.mine(42), isTrue);
      expect(p.mine(7), isFalse);
      expect(p.mine(null), isFalse);
    });

    test('my own posts endpoint is always mine', () {
      expect(Post.fromOwnPostJson({'id': 1}).mine(0), isTrue);
    });
  });
}
