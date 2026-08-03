// Result-card formatting: every category, profit with its currency, and the
// clock on local posts (which are time-sensitive).
import 'package:flutter_task/features/posts/data/models/post_model.dart';
import 'package:flutter_test/flutter_test.dart';

Post post(Map<String, dynamic> extra) => Post.fromJson({
      'id': 1,
      'type': 'DELIVER',
      'location': 'INTERNATIONAL',
      'beforeDate': '07/29/2026 02:30 PM',
      'weight': 5,
      ...extra,
    });

void main() {
  test('all selected categories are shown, not just the first', () {
    final p = post({
      'categoryTitle': 'Electronics',
      'categoryTitles': ['Electronics', 'Documents', 'Clothing'],
    });
    expect(p.categoriesText, 'Electronics, Documents, Clothing');
  });

  test('a single-category payload still reads correctly', () {
    expect(post({'categoryTitle': 'Documents'}).categoriesText, 'Documents');
  });

  test('profit carries its currency', () {
    expect(post({'travelerProfit': 50}).profitText, 'USD 50');
    expect(post({'travelerProfit': 49.5}).profitText, 'USD 49.50');
  });

  test('an already-formatted profit is left alone', () {
    expect(post({'profit': 'TND 50.000'}).profitText, 'TND 50.000');
  });

  test('no profit reads as null so the card can show a dash', () {
    expect(post({}).profitText, isNull);
  });

  test('local posts show the time, international just the date', () {
    final local = post({'location': 'LOCAL'});
    final intl = post({'location': 'INTERNATIONAL'});
    expect(local.dateText, contains(':'), reason: 'local needs the clock');
    expect(intl.dateText, isNot(contains(':')));
  });

  test('a no-specific-date label still wins over the clock', () {
    final p = post({'location': 'LOCAL', 'beforeDate': 'No specific date and time'});
    expect(p.dateText, isNot(contains('/')));
  });
}
