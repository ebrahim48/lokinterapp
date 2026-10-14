// A post with capacity partly booked must advertise what is actually LEFT,
// on every surface — the API sends remainingWeight for trips and requests.
import 'package:flutter/widgets.dart';
import 'package:flutter_task/core/i18n/app_translations.dart';
import 'package:flutter_task/features/posts/data/models/post_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

Post post(Map<String, dynamic> extra) => Post.fromJson({
      'id': 42,
      'type': 'DELIVER',
      'location': 'INTERNATIONAL',
      'beforeDate': '07/29/2026 12:00 AM',
      ...extra,
    });

void main() {
  setUpAll(() {
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('en');
  });

  test('20 kg posted, 10 kg taken → 10 kg is what is available', () {
    // the exact payload shape from the API doc
    final p = post({'weight': 20, 'remainingWeight': 10, 'status': 'deal'});
    expect(p.partlyBooked, isTrue);
    expect(p.availableWeight, 10);
    expect(p.weightText, '10 kg left');
  });

  test('an untouched post shows only its capacity', () {
    final p = post({'weight': 20, 'remainingWeight': 20});
    expect(p.partlyBooked, isFalse);
    expect(p.weightText, '20 kg');
    expect(p.weightDetailText, '20 kg');
  });

  test('a payload without remainingWeight falls back to the total', () {
    final p = post({'weight': 20});
    expect(p.partlyBooked, isFalse);
    expect(p.availableWeight, 20);
    expect(p.weightText, '20 kg');
  });

  test('a fully booked post reports nothing left', () {
    final p = post({'weight': 20, 'remainingWeight': 0});
    expect(p.partlyBooked, isTrue);
    expect(p.availableWeight, 0);
    expect(p.weightText, '0 kg left');
  });

  test('trips carry the same remaining figure', () {
    final p = post({'type': 'TRIP', 'weight': 50, 'remainingWeight': 12.5});
    expect(p.availableWeight, 12.5);
    expect(p.weightText, '12.5 kg left');
  });

  test('own posted trips keep it too', () {
    final p = Post.fromOwnPostJson({
      'id': 7,
      'status': 'TRIP',
      'location': 'LOCAL',
      'weight': '20',
      'remainingWeight': 10,
    });
    expect(p.availableWeight, 10);
    expect(p.weightText, '10 kg left');
  });

  test("the server's own capacity text is used as-is", () {
    final p = post({
      'type': 'TRIP',
      'weight': 20,
      'availableWeight': 10,
      'remainingWeightDisplay': '10 kg left',
    });
    expect(p.availableWeight, 10);
    expect(p.weightText, '10 kg left');
  });
}
