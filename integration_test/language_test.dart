// Verifies the language switcher: picking Français retranslates the UI and
// makes the API send X-Lang: fr.
import 'package:flutter/material.dart';
import 'package:flutter_task/core/services/language_service.dart';
import 'package:flutter_task/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

Future<void> settle(WidgetTester t, [int ms = 800]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> waitFor(WidgetTester t, Finder f,
    {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 300));
    if (f.evaluate().isNotEmpty) return true;
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('switching to French retranslates and sets X-Lang', (t) async {
    app.main();
    await settle(t, 3000);

    // welcome screen shows the English copy by default
    final gotWelcome = await waitFor(t, find.text('Continue as guest'));
    debugPrint('RESULT: english welcome = $gotWelcome header=${LanguageService.currentCode}');

    // open the language pill and pick Français
    await t.tap(find.byType(GestureDetector).first, warnIfMissed: false);
    if (!await waitFor(t, find.text('Français'))) {
      // fall back to the compact globe if the pill wasn't hit
      final globe = find.byIcon(Icons.language);
      if (globe.evaluate().isNotEmpty) await t.tap(globe.first, warnIfMissed: false);
      await waitFor(t, find.text('Français'));
    }
    await t.tap(find.text('Français').last, warnIfMissed: false);
    await settle(t, 1500);

    final frenchGuest = find.textContaining('invité').evaluate().isNotEmpty;
    debugPrint('RESULT: french welcome = $frenchGuest '
        'code=${Get.find<LanguageService>().code.value} header=${LanguageService.currentCode}');

    expect(LanguageService.currentCode, 'fr', reason: 'API header did not switch');
    expect(Get.locale?.languageCode, 'fr', reason: 'GetX locale did not switch');
    expect(frenchGuest, isTrue, reason: 'welcome copy did not translate');
  });
}
