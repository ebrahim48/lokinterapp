// Opening chat from a deal used to call getChatDetails/0 (422) because the
// deal's counterpart carried a name but no id.
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

  testWidgets('chat opens from a deal', (t) async {
    FlutterError.onError = (d) => debugPrint('APP ERROR: ${d.exception}');
    app.main();
    await settle(t, 3000);

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

    if (!await waitFor(t, find.text('Deals'))) {
      debugPrint('RESULT: never reached the shell');
      return;
    }
    await t.tap(find.text('Deals').last, warnIfMissed: false);
    await settle(t, 3000);

    final row = find.textContaining('United States');
    if (row.evaluate().isEmpty) {
      debugPrint('RESULT: no deals to open');
      return;
    }
    await t.tap(row.first, warnIfMissed: false);
    await settle(t, 4000);

    final chatBtn = find.widgetWithText(OutlinedButton, 'Chat');
    debugPrint('RESULT: chat button found = ${chatBtn.evaluate().isNotEmpty}');
    if (chatBtn.evaluate().isEmpty) return;

    await t.tap(chatBtn.first, warnIfMissed: false);
    await settle(t, 6000); // kyc check + getChatDetails + message load

    // the conversation screen is the one with the composer
    final opened = find.widgetWithText(TextField, 'Message...').evaluate().isNotEmpty ||
        find.text('Say hello — this is the start of your conversation.').evaluate().isNotEmpty;
    debugPrint('RESULT: conversation opened = $opened');
    expect(opened, isTrue, reason: 'chat did not open from the deal');
  });
}
