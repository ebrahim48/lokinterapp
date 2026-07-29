import 'package:flutter_task/core/i18n/app_translations.dart';
import 'package:flutter_test/flutter_test.dart';

// Every English key must have a French translation (and vice-versa) so nothing
// silently falls back to English mid-screen.
void main() {
  test('en and fr translation keys line up', () {
    final keys = AppTranslations().keys;
    final en = keys['en']!.keys.toSet();
    final fr = keys['fr']!.keys.toSet();
    expect(en.difference(fr), isEmpty, reason: 'keys missing a French translation');
    expect(fr.difference(en), isEmpty, reason: 'keys missing an English translation');
    expect(en, isNotEmpty);
  });
}
