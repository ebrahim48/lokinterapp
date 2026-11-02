// RECENT_UPDATE_V2 checklist: the model rules and the exact wording the
// update asked for, in English and French.
import 'dart:ui';

import 'package:flutter_task/core/i18n/app_translations.dart';
import 'package:flutter_task/core/utils/map_link.dart';
import 'package:flutter_task/features/chat/data/chat_model.dart';
import 'package:flutter_task/features/deals/data/deal_model.dart';
import 'package:flutter_task/features/posts/data/models/post_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

Post trip(Map<String, dynamic> extra) => Post.fromJson({
      'id': 1,
      'type': 'TRIP',
      'status': 'TRIP',
      'location': 'LOCAL',
      'beforeDate': '12/30/2030 03:00 PM',
      'weight': 20,
      ...extra,
    });

Deal deal(Map<String, dynamic> extra) => Deal.fromListJson({
      'id': 1,
      'location': 'INTERNATIONAL',
      'from': 'France',
      'to': 'Tunisia',
      'beforeDate': '08/01/2026 06:00 AM',
      'status': 'COMPLETED',
      'flag': 'DEAL',
      'profit': 10,
      ...extra,
    });

void main() {
  final keys = AppTranslations().keys;
  final en = keys['en']!, fr = keys['fr']!;

  setUp(() {
    Get.addTranslations(keys);
    Get.locale = const Locale('en');
  });

  group('12 wall-clock time', () {
    test('3:00 PM stays 3:00 PM in every format the API sends', () {
      for (final raw in [
        '12/30/2030 03:00 PM',
        '2030-12-30 15:00',
        '2030-12-30T15:00:00.000Z',
      ]) {
        final d = trip({'beforeDate': raw}).date;
        expect((d.hour, d.minute), (15, 0), reason: raw);
      }
      expect(trip({}).dateText, contains('3:00 PM'));
    });

    test('rawBeforeDate wins over the display date', () {
      final d = trip({
        'rawBeforeDate': '2030-12-30 15:00',
        'beforeDate': '12/30/2030 11:00 AM',
      }).date;
      expect(d.hour, 15);
    });
  });

  group('2.1 chat header', () {
    ChatPostContext ctx(String type, String date) =>
        ChatPostContext.fromJson({'id': 1, 'type': type, 'beforeDate': date})!;

    test('the old server label reads "Available upon request"', () {
      expect(ctx('TRIP', 'no specific date/time').dateText, 'Available upon request');
      expect(ctx('DELIVER', 'No specific date/time').dateText,
          'Available upon request');
      Get.locale = const Locale('fr');
      expect(ctx('TRIP', 'no specific date/time').dateText, 'Disponible sur demande');
    });

    test('a real date is unchanged', () {
      expect(ctx('TRIP', '10/17/2026').dateText, '10/17/2026');
      expect(ctx('DELIVER', '10/17/2026').dateText, contains('10/17/2026'));
    });
  });

  group('2.7 expired / fully consumed', () {
    test('hidden from my requests and trips', () {
      expect(trip({}).isInactive, isFalse);
      expect(trip({'isExpired': true}).isInactive, isTrue);
      expect(trip({'isFullyConsumed': true}).isInactive, isTrue);
    });
  });

  group('my requests and trips rows', () {
    Post own(Map<String, dynamic> extra) => Post.fromOwnPostJson({
          'id': 1,
          'status': 'DELIVER',
          'location': 'INTERNATIONAL',
          'from': 'France',
          'to': 'Tunisia',
          'beforeDate': '12/30/2030',
          'flag': 'POST',
          ...extra,
        });

    test('1.5 the profit keeps the currency the sender picked', () {
      expect(own({'profit': 50, 'currency': 'TND'}).profitText, 'TND 50');
      expect(own({'profit': 50}).profitText, 'USD 50');
    });

    test('2.1 "Available upon request" only lives for the day it was posted', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      Post noDate(DateTime created) => own({
            'beforeDate': 'Available upon request',
            'createdAt': created.toIso8601String(),
          });
      expect(noDate(yesterday).isInactive, isTrue);
      expect(noDate(now).isInactive, isFalse);
    });
  });

  group('2.6 remaining weight', () {
    test('a trip shows the server text, e.g. "10 kg left"', () {
      expect(trip({'remainingWeightDisplay': '10 kg left'}).weightText, '10 kg left');
    });
  });

  group('2.8 pickup / drop-off links', () {
    test('the API link opens Maps', () {
      const link = 'https://www.google.com/maps/search/?api=1&query=Tunis';
      expect(mapUrl(link, 'Tunis'), link);
    });

    test('an empty location is "-" and opens nothing', () {
      expect(hasPlace('-'), isFalse);
      expect(hasPlace(''), isFalse);
      expect(
          mapUrl('https://www.google.com/maps/search/?api=1&query=-', '-'), isNull);
    });

    test('a place with no link still opens a search', () {
      expect(mapUrl(null, 'Sfax'), contains('query=Sfax'));
    });
  });

  group('13 remaining attempts', () {
    test('2, 1 and none left', () {
      expect(deal({'remainingAttempts': 2}).remainingAttemptsText,
          '2 attempts remaining');
      expect(deal({'remainingAttempts': 1}).remainingAttemptsText,
          '1 attempt remaining');
      expect(deal({'remainingAttempts': 0}).remainingAttemptsText,
          'Maximum attempts reached');
    });
  });

  group('16 one-time rating', () {
    test('a rated deal cannot be rated again', () {
      expect(deal({}).rateable, isTrue);
      expect(deal({'hasRated': true}).rateable, isFalse);
      expect(deal({'hasRated': true, 'canRate': true}).rateable, isFalse);
    });
  });

  group('wording', () {
    void same(String key, String english, [String? french]) {
      expect(en[key], english, reason: key);
      if (french != null) expect(fr[key], french, reason: key);
    }

    test('1.3 deposit checkbox', () {
      same('require_a_security_deposit_from_the_traveler',
          'Require security deposit from the carrier.');
    });

    test('1.4 converter note', () {
      same('we_charge_in_usd_note',
          'We charge in USD. Use the converter below to see approximately '
              'how much you will pay in your currency.');
    });

    test('2.1 available upon request', () {
      same('no_specific_date_time', 'Available upon request',
          'Disponible sur demande');
    });

    test('2.5 available weight', () {
      same('available_weight', 'Available Weight', 'Poids disponible');
    });

    test('4.1 country of residence', () {
      same('country_of_residence', 'Country of Residence', 'Pays de résidence');
    });

    test('7.1 ongoing button', () {
      same('upload_purchase_video_check_as_ongoing',
          'Record Purchase / Pickup Video & Check as Ongoing');
    });

    test('8.1 QR instruction', () {
      same('receiver_qr_hint',
          'You can share this QR code with the receiver. The carrier needs to '
              'scan it to confirm delivery.');
    });

    test('13 counter texts', () {
      same('maximum_attempts_reached', 'Maximum attempts reached');
      same('one_attempt_remaining', '1 attempt remaining');
    });
  });
}
