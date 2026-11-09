import 'package:flutter_task/features/auth/data/models/auth_user.dart';
import 'package:flutter_task/features/chat/data/chat_model.dart';
import 'package:flutter_task/features/deals/data/deal_model.dart';
import 'package:flutter_task/features/deals/data/tracking_models.dart';
import 'package:flutter_task/features/fees/data/fee_models.dart';
import 'package:flutter_test/flutter_test.dart';

// Nov 2026 local & international update — payload parsing the new screens
// depend on (GUIDE Screens 2–11).
void main() {
  group('fee restrictions on the profile (GUIDE Screen 10)', () {
    test('blocked actions come from feeRestrictions', () {
      final u = AuthUser.fromJson({
        'id': 1,
        'isOverdue': true,
        'feeRestrictions': {
          'restricted': true,
          'blocked': ['POST_TRIP', 'ACCEPT_DEAL', 'NEW_CHAT'],
          'overdue': ['TND'],
        },
      });
      expect(u.feeRestricted, isTrue);
      expect(u.feeBlocks('POST_TRIP'), isTrue);
      expect(u.feeBlocks('NEW_CHAT'), isTrue);
      expect(u.overdueCurrencies, ['TND']);
    });

    test('a restriction without a list blocks all three', () {
      final u = AuthUser.fromJson({'id': 1, 'isOverdue': true});
      expect(u.feeBlocks('ACCEPT_DEAL'), isTrue);
    });

    test('no restriction blocks nothing and survives the cache', () {
      final u = AuthUser.fromJson({'id': 1});
      expect(u.feeBlocks('POST_TRIP'), isFalse);
      final r = AuthUser.fromJson({
        'id': 1,
        'feeRestrictions': {'restricted': true, 'blocked': ['POST_TRIP']},
      });
      expect(AuthUser.fromJson(r.toJson()).feeBlocks('POST_TRIP'), isTrue);
      expect(AuthUser.fromJson(r.toJson()).feeBlocks('NEW_CHAT'), isFalse);
    });
  });

  group('ledgers (GUIDE Screen 9)', () {
    test('reads data.ledgers[] — TND first, statuses, due date', () {
      final s = LedgerSummary.fromJson({
        'is_overdue': false,
        'ledgers': [
          {
            'currency': 'USD',
            'threshold': 25,
            'currentBalance': 0,
            'frozenBalance': 25.85,
            'totalDue': 25.85,
            'status': 'PAYMENT_REQUIRED',
            'isOverdue': false,
            'dueAt': '2026-11-16T12:00:00Z',
          },
          {
            'currency': 'TND',
            'threshold': 15,
            'currentBalance': 12.4,
            'frozenBalance': 0,
            'totalDue': 12.4,
            'status': 'ACTIVE',
          },
        ],
      });
      expect(s.ledgers.first.currency, 'TND');
      expect(s.local!.status, LedgerStatus.active);
      expect(s.local!.money(12.4), '12.400 TND');
      expect(s.international!.status, LedgerStatus.paymentRequired);
      expect(s.international!.progress, greaterThan(1));
      expect(s.international!.money(25.85), '\$25.85 USD');
      expect(s.international!.dueAt, isNotNull);
      expect(s.isOverdue, isFalse);
    });

    test('falls back to the keyed shape', () {
      final s = LedgerSummary.fromJson({
        'local_tunisia_ledger': {'currentBalance': 15.4, 'status': 'OVERDUE'},
        'international_ledger': {'currentBalance': 23.7},
      });
      expect(s.local!.totalDue, 15.4);
      expect(s.local!.isOverdue, isTrue);
      expect(s.international!.threshold, 25);
      expect(s.isOverdue, isTrue);
    });
  });

  group('deal payload additions', () {
    Deal deal(Map<String, dynamic> extra) => Deal.fromJson({
          'id': 7,
          'referenceId': 'REF7',
          'type': 'DELIVER',
          'location': 'LOCAL',
          'status': 'OUTGOING',
          'isTraveler': true,
          ...extra,
        });

    test('QR token, pins and the server accept roles', () {
      final d = deal({
        'deliveryQrToken': 'tok-123',
        'pickupLocation': 'Tunis',
        'pickupLat': 36.8,
        'pickupLng': '10.18',
        'dropoffLocation': '-',
        'canAcceptDeal': false,
        'isProposer': true,
      });
      expect(d.handoverQrData, 'tok-123');
      expect(d.extras.hasPickupPin, isTrue);
      expect(d.extras.dropoffLocation, isNull); // "-" means nobody filled it in
      expect(d.isProposer, isTrue);
      expect(d.trackingAvailable, isTrue);
    });

    test('older deals keep the public link QR', () {
      final d = deal({});
      expect(d.handoverQrData, contains('deal-details/REF7'));
    });

    test('platform fee with tier and next tier', () {
      final fee = deal({
        'platformFee': {
          'applies': true,
          'status': 'FINALIZED',
          'ledger': 'LOCAL',
          'currency': 'TND',
          'amount': '0.900',
          'tier': {'index': 1, 'from': 1, 'to': 10},
          'period': {'type': 'CALENDAR_MONTH', 'count': 5},
          'nextTier': {'rate': '0.800', 'dealsRemaining': 5},
        },
      }).extras.platformFee!;
      expect(fee.amountLabel, '0.900 TND');
      expect(fee.isLocal, isTrue);
      expect(fee.dealsToNextTier, 5);
      expect(fee.isPending, isFalse);
    });
  });

  group('chat post context for the local deal form', () {
    test('a Tunisia local request pre-fills pins and deadline', () {
      final p = ChatPostContext.fromJson({
        'id': 3,
        'type': 'DELIVER',
        'location': 'LOCAL',
        'fromCountry': {'name': 'Tunisia', 'iso2': 'TN'},
        'pickupLocation': 'Tunis',
        'pickupLat': 36.8,
        'pickupLng': 10.18,
        'dropoffLat': '35.89',
        'dropoffLng': '10.59',
        'beforeDate': '2030-11-10T15:00:00Z',
      })!;
      expect(p.isTunisiaLocal, isTrue);
      expect(p.pickupLat, 36.8);
      expect(p.dropoffLat, 35.89);
      expect(p.deadline, isNotNull);
    });

    test('an international post is not local', () {
      final p = ChatPostContext.fromJson({'id': 3, 'type': 'TRIP', 'location': 'INTERNATIONAL'})!;
      expect(p.isTunisiaLocal, isFalse);
    });
  });

  group('tracking link (GUIDE Screen 6.2)', () {
    test('age thresholds', () {
      final now = DateTime.now();
      expect(TrackingLinkX.fromAge(now.subtract(const Duration(seconds: 30))), TrackingLink.live);
      expect(TrackingLinkX.fromAge(now.subtract(const Duration(minutes: 5))), TrackingLink.delayed);
      expect(TrackingLinkX.fromAge(now.subtract(const Duration(minutes: 11))),
          TrackingLink.unavailable);
      expect(TrackingLinkX.fromAge(null), TrackingLink.unavailable);
    });

    test('snapshot reads lastLocation and the server status', () {
      final s = TrackingSnapshot.fromJson({
        'dealStatus': 'OUTGOING',
        'trackingActive': true,
        'connectionStatus': 'DELAYED',
        'lastLocation': {'latitude': 36.8, 'longitude': 10.1, 'recordedAt': '2026-11-09T10:35:12Z'},
        'pickup': {'label': 'Tunis', 'lat': 36.8, 'lng': 10.18},
      });
      expect(s.link, TrackingLink.delayed);
      expect(s.last!.latitude, 36.8);
      expect(s.pickup!.label, 'Tunis');
      expect(s.ended, isFalse);
    });
  });
}
