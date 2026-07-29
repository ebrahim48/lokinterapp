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

  testWidgets('home shows the search-for-deals section', (t) async {
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
        await settle(t, 5000);
      }
    }

    final onHome = await waitFor(t, find.text('Search for deals'),
        timeout: const Duration(seconds: 30));
    debugPrint('RESULT: search section present = $onHome');
    debugPrint('RESULT: trip button = '
        '${find.widgetWithText(OutlinedButton, 'Search for Trip').evaluate().isNotEmpty}');
    debugPrint('RESULT: delivery button = '
        '${find.widgetWithText(ElevatedButton, 'Search for Delivery Request').evaluate().isNotEmpty}');
    await settle(t, 1500);
  });
}
