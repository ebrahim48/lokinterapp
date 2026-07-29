// A trip posted without a date must keep saying so instead of showing an
// invented date (the API returns a phrase, not a parseable date).
import 'package:flutter_task/features/posts/data/models/post_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Post parse(dynamic before) => Post.fromJson({
        'id': 1,
        'type': 'TRIP',
        'location': 'LOCAL',
        'beforeDate': before,
        'weight': 10,
      });

  test('a real date is parsed, no label', () {
    final p = parse('07/29/2026 12:00 AM');
    expect(p.dateLabel, isNull);
    expect(p.date.year, 2026);
  });

  test('the API phrase is kept as a label, not turned into a date', () {
    for (final raw in [
      'no specific date/time',
      'No specific date and time',
      "Pas de date ni d'heure spécifique",
    ]) {
      expect(parse(raw).dateLabel, isNotNull, reason: raw);
    }
  });

  test('own-posts rows keep the phrase too', () {
    final p = Post.fromOwnPostJson({
      'id': 2,
      'status': 'TRIP',
      'location': 'LOCAL',
      'beforeDate': 'No specific date and time',
      'weight': '20',
    });
    expect(p.dateLabel, 'No specific date and time');
  });
}
