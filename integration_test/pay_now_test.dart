// Drives the real Pay now flow on deal #2 (this account is its sender) to see
// how far it gets: create-payment -> breakdown -> Stripe sheet.
import 'package:flutter/material.dart';
import 'package:flutter_task/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const email = 'sushil500530@gmail.com';
const password = 'Sushil@123!';

Future<void> settle(WidgetTester t, [int ms = 800]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> waitFor(WidgetTester t, Finder f,
    {Duration timeout = const Duration(seconds: 25)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 300));
    if (f.evaluate().isNotEmpty) return true;
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pay now reaches the stripe sheet', (t) async {
    FlutterError.onError = (d) => debugPrint('APP ERROR: ${d.exception}');
    app.main();
    await settle(t, 3000);

    // login if we're not already in
    if (await waitFor(t, find.text('Continue as guest'), timeout: const Duration(seconds: 8))) {
      await t.tap(find.widgetWithText(ElevatedButton, 'Login').last, warnIfMissed: false);
      await settle(t, 1500);
      final fields = find.byType(TextField);
      if (await waitFor(t, fields)) {
        await t.enterText(fields.at(0), email);
        await t.enterText(fields.at(1), password);
        await settle(t);
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(t, 800);
        await t.tap(find.widgetWithText(ElevatedButton, 'Login'));
        await settle(t, 4000);
      }
    }

    // Deals tab
    if (!await waitFor(t, find.text('Deals'))) {
      debugPrint('RESULT: never reached the shell');
      return;
    }
    await t.tap(find.text('Deals').last, warnIfMissed: false);
    await settle(t, 3000);

    void dump(String where) {
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty);
      debugPrint('SCREEN[$where]: ${texts.join(' | ')}');
    }

    dump('deals-list');

    // open the first deal that offers a payment
    final payFinder = find.text('Pay now');
    var opened = false;
    // deal #2 is the one this account sends on — its counterpart is Test User
    for (final label in ['Test User', '#2']) {
      final row = find.textContaining(label);
      if (row.evaluate().isNotEmpty) {
        await t.tap(row.first, warnIfMissed: false);
        await settle(t, 3000);
        opened = true;
        break;
      }
    }
    debugPrint('RESULT: opened a deal = $opened');

    // the actions sit at the bottom of a lazily-built list — scroll them in
    final scrollable = find.byType(Scrollable);
    for (var i = 0; i < 8 && payFinder.evaluate().isEmpty; i++) {
      if (scrollable.evaluate().isEmpty) break;
      await t.drag(scrollable.first, const Offset(0, -400));
      await settle(t, 500);
    }

    if (payFinder.evaluate().isEmpty) {
      dump('deal-detail');
      debugPrint('RESULT: no "Pay now" on this screen');
      return;
    }
    debugPrint('RESULT: pay now buttons on screen = ${payFinder.evaluate().length}');

    await t.tap(payFinder.first, warnIfMissed: false);
    await settle(t, 5000); // create-payment round trip

    final breakdown = find.text('Payment breakdown');
    debugPrint('RESULT: breakdown dialog = ${breakdown.evaluate().isNotEmpty}');
    if (breakdown.evaluate().isNotEmpty) {
      await t.tap(find.widgetWithText(ElevatedButton, 'Continue'), warnIfMissed: false);
    }
    // hold here so the native Stripe sheet (if it opens) can be screenshotted
    await settle(t, 15000);
    debugPrint('RESULT: done');
  });
}
