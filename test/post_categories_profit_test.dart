// The API now returns several categories on a delivery request and the
// offered traveler profit; both must survive parsing.
import 'package:flutter_task/features/posts/data/models/post_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a delivery request keeps every category', () {
    final p = Post.fromJson({
      'id': 1,
      'type': 'DELIVER',
      'location': 'INTERNATIONAL',
      'beforeDate': '07/29/2026 12:00 AM',
      'weight': 5,
      'categoryId': 3,
      'categoryTitle': 'Electronics',
      'categoryTitles': ['Electronics', 'Documents'],
    });
    expect(p.categories, ['Electronics', 'Documents']);
    expect(p.category, 'Electronics');
  });

  test('an older single-category payload still works', () {
    final p = Post.fromJson({
      'id': 2,
      'type': 'DELIVER',
      'location': 'LOCAL',
      'beforeDate': '07/29/2026 12:00 AM',
      'weight': 2,
      'categoryTitle': 'Documents',
    });
    expect(p.categories, ['Documents']);
  });

  test('traveler profit is read from the new field', () {
    final p = Post.fromJson({
      'id': 3,
      'type': 'DELIVER',
      'location': 'LOCAL',
      'beforeDate': '07/29/2026 12:00 AM',
      'weight': 1,
      'travelerProfit': 50.0,
    });
    expect(p.profit, '50.0');
  });

  test('trips still expose their rejected categories', () {
    final p = Post.fromJson({
      'id': 4,
      'type': 'TRIP',
      'location': 'LOCAL',
      'beforeDate': '07/29/2026 12:00 AM',
      'weight': 20,
      'remainingWeight': 9,
      'rejectedCategoriesTitles': ['Bundle Fuse', 'Demo Categ'],
    });
    expect(p.rejectedCategories, ['Bundle Fuse', 'Demo Categ']);
    expect(p.remainingWeight, 9);
  });
}
