// Mirrors the website's chat gating (chat.store isDealSender +
// deals-actions canRequestDeal) against the documented API examples.
import 'package:flutter_task/features/chat/data/chat_model.dart';
import 'package:flutter_test/flutter_test.dart';

ChatPostContext post(String type, int ownerId) =>
    ChatPostContext(id: 1, type: type, ownerId: ownerId);

void main() {
  group('isDealSender', () {
    test('A: TRIP owned by the other party — I am the sender', () {
      expect(post('TRIP', 10).isSender(5), isTrue);
    });

    test('B: TRIP owned by me — I am the traveler, not the sender', () {
      expect(post('TRIP', 10).isSender(10), isFalse);
    });

    test('C: DELIVER owned by me — I am the sender', () {
      expect(post('DELIVER', 5).isSender(5), isTrue);
    });

    test('D: DELIVER owned by the other party — not the sender', () {
      expect(post('DELIVER', 5).isSender(20), isFalse);
    });
  });

  group('canRequestDeal', () {
    final asSender = post('DELIVER', 5); // me = 5
    final asTraveler = post('DELIVER', 5); // me = 20

    test('sender + no deal shows the confirm button', () {
      expect(asSender.canRequestDeal(5, null), isTrue);
      expect(asSender.canRequestDeal(5, ''), isTrue);
    });

    test('sender + closed deal may propose again', () {
      for (final s in ['CANCELED', 'CANCELLED', 'REJECTED']) {
        expect(asSender.canRequestDeal(5, s), isTrue, reason: s);
      }
    });

    test('sender + live deal hides the confirm button', () {
      for (final s in ['PENDING', 'ACCEPTED', 'OUTGOING', 'COMPLETED', 'DISPUTED']) {
        expect(asSender.canRequestDeal(5, s), isFalse, reason: s);
      }
    });

    test('traveler never sees the confirm button', () {
      for (final s in [null, '', 'CANCELED', 'REJECTED', 'PENDING']) {
        expect(asTraveler.canRequestDeal(20, s), isFalse, reason: '$s');
      }
    });
  });

  group('never both users in one chat', () {
    // Case 1 — A creates a TRIP (id 10), B finds it (id 5)
    test('TRIP: only the finder sees Confirm, never the creator', () {
      final trip = post('TRIP', 10);
      expect(trip.canRequestDeal(5, null), isTrue, reason: 'finder = sender');
      expect(trip.canRequestDeal(10, null), isFalse, reason: 'creator = traveler');
    });

    // Case 2 — A creates a DELIVER request (id 5), B the traveler messages them
    test('DELIVER: only the creator sees Confirm, never the traveler', () {
      final req = post('DELIVER', 5);
      expect(req.canRequestDeal(5, null), isTrue, reason: 'creator = sender');
      expect(req.canRequestDeal(20, null), isFalse, reason: 'traveler');
    });

    test('exactly one side qualifies, for every status', () {
      for (final type in ['TRIP', 'DELIVER']) {
        final p = post(type, 10);
        for (final s in [null, '', 'CANCELED', 'REJECTED', 'PENDING', 'ACCEPTED',
                         'OUTGOING', 'COMPLETED', 'DISPUTED']) {
          final owner = p.canRequestDeal(10, s);
          final other = p.canRequestDeal(5, s);
          expect(owner && other, isFalse,
              reason: 'both users saw Confirm on $type/$s');
        }
      }
    });
  });

  group('route pill', () {
    test('DELIVER prefixes "Before", TRIP does not', () {
      expect(post('DELIVER', 1).isDeliver, isTrue);
      expect(post('TRIP', 1).isDeliver, isFalse);
    });

    test('local posts read cities, international reads countries', () {
      final local = ChatPostContext.fromJson({
        'id': 1,
        'type': 'TRIP',
        'location': 'LOCAL',
        'fromCity': {'name': 'Sfax'},
        'toCity': {'name': 'Tunis'},
        'fromCountry': {'name': 'Tunisia'},
        'toCountry': {'name': 'Tunisia'},
      })!;
      expect(local.from, 'Sfax');
      expect(local.to, 'Tunis');

      final intl = ChatPostContext.fromJson({
        'id': 2,
        'type': 'TRIP',
        'location': 'INTERNATIONAL',
        'fromCity': {'name': 'Algiers'},
        'fromCountry': {'name': 'Algeria'},
        'toCountry': {'name': 'Tunisia'},
      })!;
      expect(intl.from, 'Algeria');
      expect(intl.to, 'Tunisia');
    });
  });
}
