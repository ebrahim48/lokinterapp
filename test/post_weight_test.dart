import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// The API validates `weight` as an integer. Posts come back as "10", the app
// parses that into a double, and sending the double straight back produced
// "10.0" — a 422 on updatePost. Weight must serialise without a decimal.
void main() {
  String weightIn(dynamic value) =>
      FormData.fromMap({'weight': value}).fields.firstWhere((e) => e.key == 'weight').value;

  test('weight is sent as a whole number', () {
    const double parsed = 10.0; // what post_model gives us back for "10"
    expect(weightIn(parsed), '10.0', reason: 'the double form is what the API rejected');
    expect(weightIn(parsed.round()), '10');
  });
}
