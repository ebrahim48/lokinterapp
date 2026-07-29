// Proves the local-deal city fix: cities load from the bundled asset even
// though the backend cities API returns an empty list.
import 'package:flutter/material.dart';
import 'package:flutter_task/features/lookups/data/lookups_repository.dart';
import 'package:flutter_task/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> settle(WidgetTester t, [int ms = 2500]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local cities load from the bundled asset', (t) async {
    app.main();
    await settle(t, 3000);

    final repo = LookupsRepository();

    final countries = await repo.countries();
    final tn = countries.firstWhere((c) => c.iso2 == 'TN');
    debugPrint('RESULT countries=${countries.length} '
        'TN.phoneCode=${tn.phoneCode} emoji=${tn.emoji}');

    for (final iso in ['TN', 'DZ', 'US']) {
      final cities = await repo.cities(iso);
      debugPrint('RESULT cities[$iso]=${cities.length} '
          'first=${cities.isEmpty ? "-" : cities.first.name}');
      expect(cities, isNotEmpty, reason: '$iso cities should load from asset');
    }

    expect(tn.phoneCode, '216', reason: 'Tunisia dial code drives the phone prefix');
  });
}
