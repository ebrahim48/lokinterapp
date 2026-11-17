import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_task/core/widgets/places_map.dart';

void main() {
  const a = LatLng(23.8, 90.4), b = LatLng(23.7, 90.5);

  test('uses place names when given', () {
    final u = directionsUri(a, b,
        fromLabel: '49 Bir Uttam AK Khandakar Rd, Dhaka', toLabel: 'Paity Rd, Demra');
    expect(u.queryParameters['origin'], '49 Bir Uttam AK Khandakar Rd, Dhaka');
    expect(u.queryParameters['destination'], 'Paity Rd, Demra');
    expect(u.queryParameters['api'], '1');
  });

  test('falls back to coordinates for empty or "-" labels', () {
    final u = directionsUri(a, b, fromLabel: '-', toLabel: '  ');
    expect(u.queryParameters['origin'], '23.8,90.4');
    expect(u.queryParameters['destination'], '23.7,90.5');
  });
}
