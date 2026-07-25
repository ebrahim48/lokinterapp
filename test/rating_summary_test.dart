import 'dart:convert';

import 'package:flutter_task/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// The real /rates/getUserInfo/{id} payload nests the activity counts under
// data.posts and the profile under data.user — reading them at the top level
// made Trips/Requests always show 0 and the name blank.
const _info = '''
{"averageStars":4.5,"averageStarsAsTraveler":5,"averageStarsAsSender":4,"totalRates":8,
 "posts":{"totalDelivers":4,"totalRequests":3,"totalTrips":2},
 "user":{"id":1,"name":"Sushil Hemrom",
   "avatarUrl":"http://api.ssh.bd/api/v1/media/abc/stream",
   "emailVerified":true,"phoneVerified":true,"documentVerified":true}}
''';

void main() {
  test('rating summary reads posts.* and user.*', () {
    final s = RatingSummary.fromJson(jsonDecode(_info));
    expect(s.averageStars, 4.5);
    expect(s.totalRates, 8);
    expect(s.totalTrips, 2); // was 0 — read from the wrong level
    expect(s.totalRequests, 3);
    expect(s.totalDelivers, 4);
    expect(s.userName, 'Sushil Hemrom'); // from user.name
    expect(s.avatarUrl, contains('/stream'));
    expect(s.identityVerified, isTrue);
    expect(s.phoneVerified, isTrue);
    expect(s.emailVerified, isTrue);
  });

  test('empty profile parses to zeros without throwing', () {
    final s = RatingSummary.fromJson(
        jsonDecode('{"averageStars":0,"totalRates":0,"posts":{},"user":{}}'));
    expect(s.averageStars, 0);
    expect(s.totalTrips, 0);
    expect(s.avatarUrl, isNull);
  });
}
