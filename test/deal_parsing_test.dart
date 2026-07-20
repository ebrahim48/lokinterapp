// Parses the exact payloads the live dev API returned on 2026-07-20, so a
// shape change on the backend shows up here instead of as an empty screen.
import 'dart:convert';

import 'package:flutter_task/features/deals/data/deal_model.dart';
import 'package:flutter_task/features/posts/data/models/post_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _listRow = '''
{"id":1,"location":"INTERNATIONAL","from":"United States","to":"France",
 "beforeDate":"08/01/2026 06:00 AM","status":"ACCEPTED","flag":"DEAL","profit":120,
 "countdownSeconds":null,"isPending":false,"paymentMethod":"STRIPE",
 "fundsLockedForDispute":false,"adminDecision":null,"disputeDetails":null}
''';

const _ownPostRow = '''
{"id":3,"location":"INTERNATIONAL","from":"France","to":"United States",
 "beforeDate":"08/20/2026 06:00 AM","status":"TRIP","flag":"POST"}
''';

const _detail = '''
{"id":1,"referenceId":"eyJpdiI6In...","senderId":3,"travelerId":1,"localCountry":null,
 "from":"United States","to":"France","type":"TRIP","location":"INTERNATIONAL",
 "beforeDate":"08/01/2026 06:00 AM","senderName":"Test User","travelerName":"Sushil Hemrom",
 "cost":"120","weight":"5","receiverName":"Marie Curie","receiverPhone":"+33123456789",
 "itemLink":null,"attachment":null,"attachments":[],"attachLink":null,
 "paymentMethod":"STRIPE","cancelReason":"PERSONAL_REASONS","status":"CANCELED","rate":null,
 "senderFundsHeld":false,"itemEstimatedCost":"200.00","travelerGuaranteeHeld":false,
 "dealType":"SEND","countdownSeconds":null,"isTraveler":true,"isSender":false,
 "sdRequired":true,"tripDate":"2026-07-20T00:00:00.000000Z",
 "arrivalDate":"2026-07-22T00:00:00.000000Z","dispute":null,"disputes":[],
 "isLockedByDoubleDispute":false}
''';

void main() {
  test('deal list row parses', () {
    final d = Deal.fromListJson(jsonDecode(_listRow));
    expect(d.id, 1);
    expect(d.status, DealStatus.accepted);
    expect(d.fromCountry, 'United States');
    expect(d.toCountry, 'France');
    expect(d.profitAmount, 120);
    expect(d.profitLabel, '\$120.00');
    expect(d.paymentLabel, 'Pay Online');
    expect(d.date.year, 2026);
    expect(d.date.month, 8);
  });

  test('deal detail parses, including escrow fields', () {
    final d = Deal.fromJson(jsonDecode(_detail));
    expect(d.id, 1);
    expect(d.status, DealStatus.cancelled);
    expect(d.weight, 5); // arrives as the string "5"
    expect(d.profitLabel, '\$120.00'); // cost "120"
    expect(d.depositLabel, '\$200.00'); // itemEstimatedCost "200.00"
    expect(d.sdRequired, isTrue);
    expect(d.isTraveler, isTrue);
    expect(d.isSender, isFalse);
    // traveler sees the sender as the counterpart
    expect(d.counterpart.name, 'Test User');
    expect(d.receiverName, 'Marie Curie');
    expect(d.cancelReasonLabel, 'Personal Reasons'); // code → label
    expect(d.tripDate?.day, 20);
    expect(d.arrivalDate?.day, 22);
    // cancelled deals never prompt for a card hold
    expect(d.needsGuarantee, isFalse);
  });

  test('an accepted traveler deal asks for the guarantee', () {
    final json = Map<String, dynamic>.from(jsonDecode(_detail))..['status'] = 'ACCEPTED';
    expect(Deal.fromJson(json).needsGuarantee, isTrue);

    final held = Map<String, dynamic>.from(json)..['travelerGuaranteeHeld'] = true;
    expect(Deal.fromJson(held).needsGuarantee, isFalse);
  });

  test('own posts (flag POST) keep their type and route', () {
    final p = Post.fromOwnPostJson(jsonDecode(_ownPostRow));
    expect(p.id, 3);
    expect(p.isTrip, isTrue); // status carries TRIP/DELIVER in this shape
    expect(p.from, 'France');
    expect(p.to, 'United States');
  });
}
