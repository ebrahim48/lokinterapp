// Guards the French pass: every English key must have a real French value,
// and every `.tr` key used in the code must exist in the maps.
import 'dart:io';

import 'package:flutter_task/core/i18n/app_translations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final keys = AppTranslations().keys;
  final en = keys['en']!;
  final fr = keys['fr']!;

  test('French defines every English key', () {
    expect(en.keys.where((k) => !fr.containsKey(k)), isEmpty);
  });

  test('French values are actually translated', () {
    // a handful legitimately match (USD, SWIFT / BIC, KG, International…)
    const sameByDesign = {
      'USD', 'SWIFT / BIC', 'KG', 'International', 'Local', 'Notifications',
      'Message', 'Options', 'Documents', 'Transport', 'Contact', 'Format',
      'Description', 'Transactions', 'Total', 'Min. @amount',
    };
    final identical = en.keys
        .where((k) => fr[k] == en[k])
        .where((k) => !sameByDesign.contains(en[k]))
        .where((k) => RegExp(r'[A-Za-z]{5,}').hasMatch(en[k]!))
        .toList();
    expect(identical, isEmpty, reason: 'untranslated: $identical');
  });

  test('every .tr key used in lib/ exists in the maps', () {
    final re = RegExp(r"'([^'\\\n]{2,90})'\.tr\b");
    final missing = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('i18n')) continue;
      for (final m in re.allMatches(f.readAsStringSync())) {
        final k = m.group(1)!;
        if (!en.containsKey(k)) missing.add('$k  (${f.path})');
      }
    }
    expect(missing, isEmpty, reason: 'keys with no translation:\n${missing.join('\n')}');
  });
}
