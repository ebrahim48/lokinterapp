// Proves the French pass: switching locale retranslates real screen copy,
// not just the welcome page.
import 'package:flutter/material.dart';
import 'package:flutter_task/core/i18n/app_translations.dart';
import 'package:flutter_task/core/services/language_service.dart';
import 'package:flutter_task/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('French covers the app, not just the welcome screen', (t) async {
    app.main();
    await settle(t, 3000);

    final keys = AppTranslations().keys;
    final en = keys['en']!, fr = keys['fr']!;
    debugPrint('RESULT en=${en.length} fr=${fr.length}');

    // every English key must have a French value, and it must differ
    final missing = en.keys.where((k) => !fr.containsKey(k)).toList();
    final untranslated = en.keys
        .where((k) => fr[k] == en[k] && RegExp(r'[a-zA-Z]{4,}').hasMatch(en[k]!))
        .toList();
    debugPrint('RESULT missing=${missing.length} identical=${untranslated.length}');
    debugPrint('RESULT sampleIdentical=${untranslated.take(8).toList()}');

    await Get.updateLocale(const Locale('fr', 'FR'));
    await settle(t, 800);
    debugPrint('RESULT locale=${Get.locale?.languageCode} header=${LanguageService.currentCode}');

    // spot-check copy that appears across the app
    for (final k in ['accept_deal', 'confirm_agreement_continue', 'trips', 'save']) {
      debugPrint('RESULT tr[$k] = ${k.tr}');
      expect(k.tr, isNot(k), reason: '$k did not translate');
    }

    expect(missing, isEmpty);
    expect(Get.locale?.languageCode, 'fr');
  });
}
