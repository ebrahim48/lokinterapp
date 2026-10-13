// The three deal windows: 24h to pay after acceptance, 48h after arrival
// before auto-completion, and the post-completion dispute window. Each one
// only runs in its own state, and stops once a dispute exists.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_task/core/i18n/app_translations.dart';
import 'package:flutter_task/features/deals/data/deal_model.dart';
import 'package:flutter_task/features/deals/presentation/widgets/deal_countdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

String _iso(DateTime d) => d.toUtc().toIso8601String();

void main() {
  Get.addTranslations(AppTranslations().keys);
  Get.locale = const Locale('en');

  final now = DateTime.now();

  test('unpaid online deal: 24h from acceptance', () {
    final accepted = now.subtract(const Duration(hours: 2));
    final d = Deal.fromJson({
      'id': 1, 'status': 'ACCEPTED', 'paymentMethod': 'STRIPE',
      'senderFundsHeld': false, 'acceptedAt': _iso(accepted),
    });
    expect(d.paymentDeadline!.difference(accepted), const Duration(hours: 24));
  });

  test('no payment window once paid, or for cash on delivery', () {
    final paid = Deal.fromJson({
      'id': 1, 'status': 'ACCEPTED', 'paymentMethod': 'STRIPE',
      'senderFundsHeld': true, 'acceptedAt': _iso(now),
    });
    final cod = Deal.fromJson({
      'id': 2, 'status': 'ACCEPTED', 'paymentMethod': 'CASH_ON_DELIVERY',
      'acceptedAt': _iso(now),
    });
    expect(paid.paymentDeadline, isNull);
    expect(cod.paymentDeadline, isNull);
  });

  test('48h window runs from the arrival time, not midnight of the day', () {
    final arrival = now.subtract(const Duration(hours: 2));
    final d = Deal.fromJson({
      'id': 1, 'status': 'OUTGOING',
      // the day alone would start the clock at 00:00
      'arrivalDate': '${arrival.year}-${arrival.month.toString().padLeft(2, '0')}-${arrival.day.toString().padLeft(2, '0')}',
      'arrivalAt': _iso(arrival),
    });
    expect(d.arrivalWindowEnd!.difference(arrival).inMinutes,
        const Duration(hours: 48).inMinutes);
  });

  test('arrivalDate + arrivalTime combine into the exact arrival', () {
    final d = Deal.fromJson({
      'id': 1, 'status': 'OUTGOING',
      'arrivalDate': '2026-10-05', 'arrivalTime': '14:30',
    });
    expect(d.scheduledArrival, DateTime(2026, 10, 5, 14, 30));
  });

  test("the server's autoCompleteAt wins over the computed deadline", () {
    final end = now.add(const Duration(hours: 10));
    final d = Deal.fromJson({
      'id': 1, 'status': 'OUTGOING',
      'arrivalDate': _iso(now.subtract(const Duration(hours: 1))),
      'autoCompleteAt': _iso(end),
    });
    expect(d.arrivalWindowEnd!.difference(end).inSeconds, 0);
  });

  test('before arrival: no countdown, but the window opening is known', () {
    final arrival = now.add(const Duration(hours: 5));
    final d = Deal.fromJson({
      'id': 1, 'status': 'OUTGOING', 'arrivalAt': _iso(arrival),
    });
    expect(d.arrivalWindowEnd, isNull);
    expect(d.arrivalWindowStartsAt!.difference(arrival).inSeconds, 0);
  });

  test('US display format parses with its time', () {
    final d = Deal.fromJson({
      'id': 1, 'status': 'OUTGOING', 'arrivalDate': '10/05/2026 06:15 PM',
    });
    expect(d.arrivalDate, DateTime(2026, 10, 5, 18, 15));
  });

  test('48h window starts at arrival and stops on a dispute', () {
    final arrival = now.subtract(const Duration(hours: 5));
    final ongoing = Deal.fromJson({
      'id': 1, 'status': 'OUTGOING', 'paymentMethod': 'CASH_ON_DELIVERY',
      'arrivalDate': _iso(arrival),
    });
    expect(ongoing.arrivalWindowEnd!.difference(arrival), const Duration(hours: 48));

    final notArrived = Deal.fromJson({
      'id': 2, 'status': 'OUTGOING',
      'arrivalDate': _iso(now.add(const Duration(hours: 5))),
    });
    expect(notArrived.arrivalWindowEnd, isNull);

    final disputed = Deal.fromJson({
      'id': 3, 'status': 'OUTGOING', 'hasOpenDispute': true,
      'arrivalDate': _iso(arrival),
    });
    expect(disputed.arrivalWindowEnd, isNull);
  });

  test('completed deal shows the dispute window from the list row', () {
    final end = now.add(const Duration(hours: 5));
    final d = Deal.fromListJson({
      'id': 1, 'status': 'COMPLETED', 'canDispute': true,
      'disputeWindowEnd': _iso(end),
      'completionType': 'AUTO_COMPLETED_48H',
    });
    expect(d.disputeWindowEndsAt, isNotNull);
    expect(d.isAutoCompleted, isTrue);

    final closed = Deal.fromListJson({
      'id': 2, 'status': 'COMPLETED', 'canDispute': false,
      'disputeWindowEnd': _iso(now.subtract(const Duration(minutes: 1))),
    });
    expect(closed.disputeWindowEndsAt, isNull);
  });

  test('a disputed list row carries its dispute, not a countdown', () {
    final d = Deal.fromListJson({
      'id': 1, 'status': 'COMPLETED', 'canDispute': true,
      'disputeWindowEnd': _iso(now.add(const Duration(hours: 1))),
      'hasDispute': true, 'disputeStatusLabel': 'Under Admin Review',
      'disputeReason': 'Item damaged in transit',
      'disputeAttachments': [
        {'url': 'https://example.com/1.jpg'},
        {'url': 'https://example.com/2.jpg'},
      ],
    });
    expect(d.hasDisputeRecord, isTrue);
    expect(d.disputeWindowEndsAt, isNull);
    expect(d.disputeInfo!['statusLabel'], 'Under Admin Review');
    expect((d.disputeInfo!['attachments'] as List).length, 2);
  });

  test('server auto-cancel reason reads as the 24h message', () {
    final d = Deal.fromJson({
      'id': 1, 'status': 'CANCELED',
      'cancelReason': 'Auto-cancelled – Payment not completed within 24h.',
    });
    expect(d.isAutoCancelledUnpaid, isTrue);
    expect(d.cancelReasonLabel,
        'Auto-cancelled – payment not completed within 24h.');
  });

  test('a window already over shows no timer', () {
    final unpaid = Deal.fromJson({
      'id': 33, 'status': 'ACCEPTED', 'paymentMethod': 'STRIPE',
      'senderFundsHeld': false,
      'acceptedAt': _iso(now.subtract(const Duration(days: 60))),
    });
    final lateArrival = Deal.fromJson({
      'id': 2, 'status': 'OUTGOING',
      'arrivalDate': _iso(now.subtract(const Duration(hours: 49))),
    });
    expect(unpaid.paymentDeadline, isNull);
    expect(lateArrival.arrivalWindowEnd, isNull);
  });

  test('countdown formats as HH:MM:SS', () {
    expect(DealCountdown.format(const Duration(hours: 5, minutes: 42, seconds: 16)),
        '05:42:16');
    expect(DealCountdown.format(const Duration(hours: 47, seconds: 59)), '47:00:59');
    expect(DealCountdown.format(const Duration(seconds: -3)), '00:00:00');
  });

  testWidgets('an expired timer renders nothing and asks for a reload',
      (tester) async {
    var reloads = 0;
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        home: Scaffold(
          body: DealCountdown(
            endsAt: DateTime.now().subtract(const Duration(seconds: 1)),
            window: DealWindow.payment,
            onExpired: () => reloads++,
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.textContaining('00:00:00'), findsNothing);
    expect(reloads, 1);
  });
}
