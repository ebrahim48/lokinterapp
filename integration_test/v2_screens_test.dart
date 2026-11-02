// RECENT_UPDATE_V2 screens on a real device, against the live API.
// Run after real_flow_test (login phase) with --keep-app-running so the
// session is already there. Every step runs even if an earlier one fails.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_task/core/services/session_service.dart';
import 'package:flutter_task/main.dart' as app;

Future<void> settle(WidgetTester t, [int ms = 3000]) async {
  for (var i = 0; i < ms ~/ 250; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<void> pumpUntil(WidgetTester t, Finder f, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 4; i++) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('timed out waiting for $f');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('v2 screens', (t) async {
    await app.main();
    await binding.convertFlutterSurfaceToImage();
    await settle(t, 4000); // translations register with the first frames
    await pumpUntil(t, find.text('nav.home'.tr));
    expect(Get.find<SessionService>().loggedIn, isTrue);
    await settle(t, 5000);

    final failed = <String>[];
    Future<void> step(String name, Future<void> Function() body) async {
      try {
        await body();
        debugPrint('V2 PASS $name');
      } catch (e, st) {
        failed.add(name);
        debugPrint('V2 FAIL $name: ${'$e'.split('\n').first}');
        debugPrint('V2 STACK ${'$st'.split('\n').where((l) => l.contains('v2_screens') || l.contains('lib/')).take(4).join(' | ')}');
      }
      // back to the shell's home tab for the next step
      while (Navigator.of(t.element(find.byType(Scaffold).first)).canPop()) {
        Get.back();
        await settle(t, 800);
      }
      await t.tap(find.text('nav.home'.tr));
      await settle(t, 1500);
    }

    Future<void> shot(String name) async {
      await settle(t, 600);
      await binding.takeScreenshot(name);
    }

    await step('3.1 recommended cards white in dark mode', () async {
      // the last run may have left dark mode on
      if (Get.isDarkMode) {
        await t.tap(find.byIcon(Icons.dark_mode_outlined).first);
        await settle(t, 1500);
      }
      await t.tap(find.byIcon(Icons.dark_mode_outlined).first);
      await settle(t, 1500);
      expect(Get.isDarkMode, isTrue);
      await shot('v2_01_home_dark');
      final cards = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == Colors.white &&
          w.constraints?.maxWidth != null);
      debugPrint('V2 white cards in dark mode: ${cards.evaluate().length}');
      expect(cards, findsWidgets);
      Get.changeThemeMode(ThemeMode.light);
      await settle(t, 1500);
    });

    await step('2.3/2.5 trip results: no airplane, "Available Weight"', () async {
      await t.tap(find.text('trips'.tr).last);
      await settle(t, 6000);
      await shot('v2_02_trip_results');
      for (final i in [
        Icons.flight,
        Icons.flight_takeoff,
        Icons.flight_land,
        Icons.airplanemode_active,
        Icons.airplane_ticket_outlined,
      ]) {
        expect(find.byIcon(i), findsNothing, reason: '$i');
      }
      expect(find.text('available_weight'.tr.toUpperCase()), findsWidgets);
      expect(find.textContaining('kg left'), findsWidgets);
    });

    await step('2.8 request details: pickup and drop-off shown', () async {
      await t.tap(find.text('requests'.tr).last);
      await settle(t, 6000);
      await t.tap(find.text('before'.tr.toUpperCase()).first);
      await settle(t, 4000);
      await shot('v2_03_post_details');
      expect(find.text('pickup_location'.tr), findsWidgets);
      expect(find.text('dropoff_location'.tr), findsWidgets);
    });

    await step('1.5 request currency follows the picker', () async {
      await t.tap(find.byIcon(Icons.add).last);
      await settle(t, 1200);
      await t.tap(find.text('post_a_delivery_request'.tr));
      await settle(t, 3000);
      await shot('v2_04_request_page');
      await t.tap(find.text('deliver_ready_item'.tr).first);
      await settle(t, 1500);
      await t.tap(find.text('international'.tr).last);
      await settle(t, 1500);
      await shot('v2_04b_request_form');
      debugPrint('V2 request scrollables: ${find.byType(Scrollable).evaluate().length}');
      final picker = find.byIcon(Icons.currency_exchange);
      await t.scrollUntilVisible(picker, 300,
          scrollable: find.byType(Scrollable).first, maxScrolls: 30);
      // the currency dropdown is the last arrow on the form
      final arrow = find.byIcon(Icons.keyboard_arrow_down).last;
      await t.ensureVisible(arrow);
      await settle(t, 800);
      await t.tap(arrow);
      await settle(t, 1500);
      debugPrint('V2 currency sheet open: '
          '${find.byType(BottomSheet).evaluate().isNotEmpty}, '
          'EUR rows: ${find.text('EUR').evaluate().length}');
      await shot('v2_04a_currency_picker');
      await t.tap(find.text('EUR').last);
      await settle(t, 1200);
      await shot('v2_04_request_currency_eur');
      // the picker's value and the profit field's unit
      expect(find.text('EUR'), findsNWidgets(2));
      expect(find.text('\$'), findsNothing);
    });

    await step('6.1 / 1.1 / 1.3 / 1.4 chat + agreement sheet', () async {
      // a trip's "chat" makes us the sender, so the agreement can start
      await t.tap(find.text('trips'.tr).last);
      await settle(t, 6000);
      await t.tap(find.text('chat_2'.tr).first);
      await settle(t, 6000);
      await shot('v2_05_chat');
      debugPrint('V2 chat click_here buttons: '
          '${find.text('click_here'.tr).evaluate().length}');
      final confirm = find.text('confirm_agreement_continue'.tr);
      expect(confirm, findsOneWidget, reason: 'no "Confirm agreement" bar');
      await t.tap(confirm);
      await settle(t, 3000);
      await shot('v2_06_after_confirm_tap');
      expect(find.textContaining('i_want_to'.tr, findRichText: true), findsWidgets);
      await shot('v2_06_agreement_sheet');

      // 1.4 USD on the profit even while it is empty, plus the converter note
      expect(find.text('usd'.tr), findsWidgets);
      expect(find.text('we_charge_in_usd_note'.tr), findsOneWidget);
      await t.enterText(find.byType(TextField).first, '25');
      await settle(t, 2500);

      // 1.3 deposit amount hidden until the checkbox is ticked
      final box = find.text('require_a_security_deposit_from_the_traveler'.tr);
      await t.scrollUntilVisible(box, 200,
          scrollable: find.byType(Scrollable).last, maxScrolls: 20);
      expect(find.textContaining('security_deposit_amount'.tr, findRichText: true), findsNothing);
      await shot('v2_07_deposit_unchecked');
      await t.tap(box);
      await settle(t, 1000);
      expect(find.textContaining('security_deposit_amount'.tr, findRichText: true), findsOneWidget);
      await shot('v2_08_deposit_checked');
      await t.tap(box);
      await settle(t, 800);

      // 1.1 buy & deliver can pick cash on delivery
      final wantTo = find.byIcon(Icons.local_shipping_outlined);
      await t.scrollUntilVisible(wantTo, -200,
          scrollable: find.byType(Scrollable).last, maxScrolls: 20);
      await t.tap(wantTo);
      await settle(t, 1200);
      await t.tap(find.text('buy_for_me_and_deliver'.tr).last);
      await settle(t, 1200);
      final pay = find.byIcon(Icons.credit_card);
      await t.scrollUntilVisible(pay, 300,
          scrollable: find.byType(Scrollable).last, maxScrolls: 40);
      await t.tap(pay);
      await settle(t, 1200);
      await t.tap(find.text('cash_on_delivery'.tr).last);
      await settle(t, 1200);
      await shot('v2_09_buy_and_deliver_cod');
      expect(find.text('cash_on_delivery'.tr), findsOneWidget);
      expect(find.text('buy_for_me_and_deliver'.tr), findsOneWidget);
    });

    await step('10.1 wallet: Wise minimum 10', () async {
      await t.tap(find.text('nav.profile'.tr));
      await settle(t, 2500);
      final w = find.text('wallet_payouts'.tr);
      await t.scrollUntilVisible(w, 200,
          scrollable: find.byType(Scrollable).first, maxScrolls: 20);
      await t.tap(w);
      await settle(t, 5000);
      await shot('v2_10_wallet');
      final minimums = find.textContaining('Wise');
      debugPrint('V2 wallet Wise texts: '
          '${minimums.evaluate().map((e) => (e.widget as Text).data).toList()}');
    });

    debugPrint('V2 failed steps: $failed');
    expect(failed, isEmpty);
  });
}
