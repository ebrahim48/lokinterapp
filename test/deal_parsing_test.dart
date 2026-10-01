// Parses the exact payloads the live dev API returned on 2026-07-20, so a
// shape change on the backend shows up here instead of as an empty screen.
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_task/core/i18n/app_translations.dart';
import 'package:flutter_task/features/chat/data/chat_model.dart';
import 'package:flutter_task/features/deals/data/deal_model.dart';
import 'package:flutter_task/features/posts/data/models/post_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const _listRow = '''
{"id":1,"location":"INTERNATIONAL","from":"United States","to":"France",
 "beforeDate":"08/01/2026 06:00 AM","status":"ACCEPTED","flag":"DEAL","profit":120,
 "countdownSeconds":null,"isPending":false,"paymentMethod":"STRIPE",
 "fundsLockedForDispute":false,"adminDecision":null,"disputeDetails":null}
''';

const _ownPostRow = '''
{"id":3,"location":"INTERNATIONAL","from":"France","to":"United States",
 "beforeDate":"08/20/2026 06:00 AM","weight":"20","status":"TRIP","flag":"POST"}
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
  // labels go through the app translations
  Get.addTranslations(AppTranslations().keys);
  Get.locale = const Locale('en');

  test('deal list row parses', () {
    final d = Deal.fromListJson(jsonDecode(_listRow));
    expect(d.id, 1);
    expect(d.status, DealStatus.accepted);
    expect(d.fromCountry, 'United States');
    expect(d.toCountry, 'France');
    expect(d.profitAmount, 120);
    expect(d.profitLabel, '\$120.00');
    expect(d.paymentLabel, 'Pay online');
    expect(d.date.year, 2026);
    expect(d.date.month, 8);
  });

  // the counterpart id is what opens the chat — without it the API 422s on
  // getChatDetails/0 ("A valid chat partner is required")
  test('deal detail carries the counterpart id, not just the name', () {
    final d = Deal.fromJson(jsonDecode(_detail));
    expect(d.isTraveler, isTrue); // so the other side is the sender
    expect(d.counterpart.id, 3); // senderId
    expect(d.counterpart.name, 'Test User');
  });

  // deal-flow parity with the live app: the sender shares the QR throughout,
  // and the traveler is held back until the sender's escrow is funded
  test('sender sees the receiver QR while the deal is live', () {
    Deal senderAt(String status) => Deal.fromJson(Map<String, dynamic>.from(jsonDecode(_detail))
      ..['isSender'] = true
      ..['isTraveler'] = false
      ..['status'] = status);
    expect(senderAt('PENDING').showsReceiverQr, isTrue);
    expect(senderAt('ACCEPTED').showsReceiverQr, isTrue);
    expect(senderAt('OUTGOING').showsReceiverQr, isTrue);
    expect(senderAt('DISPUTES').showsReceiverQr, isTrue); // website: shown while disputed
    expect(senderAt('COMPLETED').showsReceiverQr, isFalse);
    expect(senderAt('CANCELED').showsReceiverQr, isFalse);
    // the traveler never shows the QR — they scan it, not share it
    expect(Deal.fromJson(jsonDecode(_detail)).showsReceiverQr, isFalse);
  });

  test('traveler waits for the sender payment before starting', () {
    Map<String, dynamic> base() => Map<String, dynamic>.from(jsonDecode(_detail))
      ..['isTraveler'] = true
      ..['isSender'] = false
      ..['status'] = 'ACCEPTED'
      ..['paymentMethod'] = 'STRIPE'
      ..['sdRequired'] = false;

    final unpaid = Deal.fromJson(base()..['senderFundsHeld'] = false);
    expect(unpaid.travelerWaitingOnPayment, isTrue);
    expect(unpaid.travelerCanStart, isFalse);

    final paid = Deal.fromJson(base()..['senderFundsHeld'] = true);
    expect(paid.travelerWaitingOnPayment, isFalse);
    expect(paid.travelerCanStart, isTrue);

    // a security deposit must also be in place before starting
    final needsGuarantee = Deal.fromJson(base()
      ..['senderFundsHeld'] = true
      ..['sdRequired'] = true
      ..['travelerGuaranteeHeld'] = false);
    expect(needsGuarantee.travelerCanStart, isFalse);

    // cash deals need no escrow, so the sender counts as already paid
    final cod = Deal.fromJson(base()
      ..['paymentMethod'] = 'CASH_ON_DELIVERY'
      ..['senderFundsHeld'] = false);
    expect(cod.senderHasPaid, isTrue);
    expect(cod.travelerCanStart, isTrue);
  });

  // the receiver's QR must encode the deal-details URL with the reference code
  test('deal confirmation link is the web deal-details url with the ref code', () {
    final d = Deal.fromJson(jsonDecode(_detail));
    expect(d.confirmationLink, 'https://lokinter.ssh.bd/deal-details/${d.refId}');
    expect(d.confirmationLink, contains('/deal-details/eyJ')); // the encrypted ref id
  });

  // website: the deal's SENDER is always the proposer — on a trip and on a
  // delivery request alike — and only the traveler accepts/rejects
  test('the proposer is the sender, regardless of post type', () {
    Deal deal(String type, bool iAmSender) =>
        Deal.fromJson(Map<String, dynamic>.from(jsonDecode(_detail))
          ..['type'] = type
          ..['isSender'] = iAmSender
          ..['isTraveler'] = !iAmSender);
    expect(deal('TRIP', true).isProposer, isTrue); // sender proposes
    expect(deal('TRIP', false).isProposer, isFalse); // traveler accepts
    expect(deal('DELIVER', true).isProposer, isTrue); // sender proposes here too
    expect(deal('DELIVER', false).isProposer, isFalse); // traveler accepts
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
    expect(d.cancelReasonLabel, 'Personal reasons'); // code → label
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

  test('the sender is prompted to pay once the traveler accepts', () {
    final json = Map<String, dynamic>.from(jsonDecode(_detail))
      ..['status'] = 'ACCEPTED'
      ..['isSender'] = true
      ..['isTraveler'] = false;
    final d = Deal.fromJson(json);
    expect(d.needsPayment, isTrue);
    expect(d.needsGuarantee, isFalse); // guarantee is the traveler's side
    // once escrow holds the funds the prompt goes away
    final paid = Map<String, dynamic>.from(json)..['senderFundsHeld'] = true;
    expect(Deal.fromJson(paid).needsPayment, isFalse);
  });

  test('system chat messages carry the deal they refer to', () {
    const raw = '''
    {"id":5,"userId":null,"type":"system","message":"Deal status has been changed to ACCEPTED.",
     "file":null,"fileUrl":null,"isRead":false,"createdAt":"2026-07-20T09:17:56.000000Z",
     "user":{"id":null,"name":null},"systemMessageType":"DEAL_ACCEPT",
     "data":{"id":"2","status":"DEAL_ACCEPT"}}
    ''';
    final m = ChatMessage.fromJson(jsonDecode(raw), 1);
    expect(m.isSystem, isTrue);
    expect(m.systemType, 'DEAL_ACCEPT');
    expect(m.dealId, 2); // arrives as the string "2"
    expect(m.fromMe, isFalse); // null userId must not read as "mine"
  });

  test('attachment-only messages survive a null body', () {
    const raw = '''
    {"id":12,"userId":1,"type":"user","message":null,
     "fileUrl":"https://dev-dashboard.lokinter.com/api/v1/media/abc/stream",
     "createdAt":"2026-07-20T10:44:16.000000Z","systemMessageType":null,"data":null}
    ''';
    final m = ChatMessage.fromJson(jsonDecode(raw), 1);
    expect(m.text, '');
    expect(m.fromMe, isTrue);
    // media host is rewritten to the one that actually serves the file
    expect(m.attachmentUrl, contains('api.ssh.bd'));
  });

  // media urls end in /stream with no extension, so the mime type is the only
  // way the bubble can tell an image from a document
  test('image attachments carry their mime type and real filename', () {
    const raw = '''
    {"id":12,"userId":1,"type":"user","message":null,
     "file":{"mediaId":"f107","url":"https://dev-dashboard.lokinter.com/api/v1/media/f107/stream",
             "mimeType":"image/png","size":1225946,
             "fileName":"Screenshot_20260719-135609_LinkedIn.png","name":"Screenshot_20260719-135609_LinkedIn"},
     "fileUrl":"https://dev-dashboard.lokinter.com/api/v1/media/f107/stream",
     "createdAt":"2026-07-20T10:44:16.000000Z"}
    ''';
    final m = ChatMessage.fromJson(jsonDecode(raw), 1);
    expect(m.attachmentMime, 'image/png');
    expect(m.attachmentName, 'Screenshot_20260719-135609_LinkedIn.png');
    // the url alone gives no hint — it ends in "stream"
    expect(m.attachmentUrl, endsWith('/stream'));
  });

  // only the sender may propose a deal (website canRequestDeal): the sender is
  // the delivery-request owner, or the non-owner on a trip post
  test('post context resolves who the sender is', () {
    ChatPostContext ctx(String type, int ownerId) =>
        ChatPostContext.fromJson({'id': 5, 'type': type, 'user': {'id': ownerId}})!;
    // trip post: owner is the traveler, the other party is the sender
    expect(ctx('TRIP', 9).isSender(1), isTrue); // I (1) don't own it → sender
    expect(ctx('TRIP', 1).isSender(1), isFalse); // I own the trip → traveler
    // delivery request: the owner is the sender
    expect(ctx('DELIVER', 1).isSender(1), isTrue); // I own the request → sender
    expect(ctx('DELIVER', 9).isSender(1), isFalse); // not mine → I'm the traveler
    // owner unknown → fall back to the trip-post assumption
    final noOwner = ChatPostContext.fromJson({'id': 5, 'type': 'TRIP'})!;
    expect(noOwner.isSender(1), isTrue);
  });

  test('chat details deal ref drives the Show Deal bar', () {
    expect(ChatDealRef.fromJson(null), isNull);
    final ref = ChatDealRef.fromJson({'id': 2, 'status': 'ACCEPTED'});
    expect(ref?.id, 2);
    expect(ref?.status, 'ACCEPTED');
  });

  test('chat post context reads the route for the header', () {
    const raw = '''
    {"id":2,"type":"DELIVER","location":"INTERNATIONAL",
     "fromCountry":{"id":1,"iso2":"US","name":"United States"},
     "toCountry":{"id":75,"iso2":"FR","name":"France"},
     "fromCity":[],"toCity":[],"beforeDate":"08/01/2026 06:00 AM"}
    ''';
    final p = ChatPostContext.fromJson(jsonDecode(raw))!;
    expect(p.id, 2);
    expect(p.from, 'United States'); // empty [] city falls back to country
    expect(p.to, 'France');
    expect(p.beforeDate, '08/01/2026 06:00 AM');
  });

  test('own posts (flag POST) keep their type and route', () {
    final p = Post.fromOwnPostJson(jsonDecode(_ownPostRow));
    expect(p.id, 3);
    expect(p.isTrip, isTrue); // status carries TRIP/DELIVER in this shape
    expect(p.from, 'France');
    expect(p.to, 'United States');
    expect(p.weight, 20); // the row carries it as the string "20"
  });
}
