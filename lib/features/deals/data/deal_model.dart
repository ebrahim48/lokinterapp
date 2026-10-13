import 'package:flutter/material.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/media_url.dart';
import '../../posts/data/models/post_model.dart';
import 'package:get/get.dart';

enum DealStatus { pending, accepted, outgoing, completed, cancelled, disputes }

// Reasons offered when cancelling — the API stores them as codes
// (a live deal came back with "PERSONAL_REASONS").
enum CancelReason {
  packageConcern('PACKAGE_CONCERN', 'cancel_reason_package_concern'),
  tripChanged('TRIP_CHANGED', 'cancel_reason_trip_changed'),
  cantFindItem('CANT_FIND_ITEM', 'cancel_reason_cant_find_item'),
  pointsProblem('DELIVERY_PICKUP_POINTS_PROBLEM', 'cancel_reason_points_problem'),
  paymentConcerns('PAYMENT_CONCERNS', 'cancel_reason_payment_concerns'),
  personalReasons('PERSONAL_REASONS', 'cancel_reason_personal_reasons');

  final String code;
  final String _labelKey;
  const CancelReason(this.code, this._labelKey);

  String get label => _labelKey.tr;
}

List<String> _attachUrls(dynamic raw) => (raw as List? ?? const [])
    .whereType<Map>()
    .map((e) => fixMediaUrl(e['signedUrl'] ?? e['url']))
    .whereType<String>()
    .toList();

class Deal {
  final int id;
  final String refId;
  final PostType type;
  final PostLocation location;
  final String fromCountry;
  final String toCountry;
  final DateTime date;
  final double weight;
  final double? profitAmount; // traveler reward
  final DealStatus status;
  final PostUser counterpart;
  final bool isSender;
  final bool isTraveler;
  final String paymentMethod;
  final String? receiverName;
  final String? receiverPhone;
  final String? attachUrl;
  // every picture the sender attached (the API returns an `attachments` array)
  final List<String> attachUrls;
  // item details the sender filled in — the traveler needs to see these
  final String? itemName;
  final String? notes;
  final String? itemLink;
  // SEND | BUY_AND_DELIVER — the delivery type the sender chose
  final String? wantTo;
  final String? cancelReason;
  // escrow / security deposit
  final bool sdRequired;
  final double? itemEstimatedCost;
  final bool travelerGuaranteeHeld;
  final bool senderFundsHeld;
  final int? countdownSeconds;
  final DateTime? tripDate;
  final DateTime? arrivalDate;
  /// The exact scheduled arrival (date + time the sender picked), when the
  /// server returns it — arrivalDate alone is often just the day.
  final DateTime? arrivalAt;
  /// Server-computed end of the 48h auto-completion window, when sent.
  final DateTime? autoCompleteAt;
  final bool fundsLockedForDispute;
  final Map<String, dynamic>? dispute;
  /// When false the "Mark Completed" button must be hidden.
  final bool canMarkCompleted;
  /// Set by the server when a dispute is open — hides "Mark Completed".
  final bool hasOpenDispute;
  /// Full dispute detail block returned by GET /disputes/deal/{id}.
  final Map<String, dynamic>? disputeDetails;
  /// When the traveler accepted — the sender's 24h payment window starts here.
  final DateTime? acceptedAt;
  /// End of the post-completion dispute window (2h local / 6h international).
  final DateTime? disputeWindowEnd;
  /// Server says a dispute can still be opened.
  final bool canDispute;
  /// QR_SCAN | SENDER_CONFIRMATION | AUTO_COMPLETED_48H
  final String? completionType;

  const Deal({
    this.id = 0,
    required this.refId,
    required this.type,
    required this.location,
    required this.fromCountry,
    required this.toCountry,
    required this.date,
    required this.weight,
    this.profitAmount,
    required this.status,
    required this.counterpart,
    this.isSender = false,
    this.isTraveler = false,
    this.paymentMethod = '',
    this.receiverName,
    this.receiverPhone,
    this.attachUrl,
    this.attachUrls = const [],
    this.itemName,
    this.notes,
    this.itemLink,
    this.wantTo,
    this.cancelReason,
    this.sdRequired = false,
    this.itemEstimatedCost,
    this.travelerGuaranteeHeld = false,
    this.senderFundsHeld = false,
    this.countdownSeconds,
    this.tripDate,
    this.arrivalDate,
    this.arrivalAt,
    this.autoCompleteAt,
    this.fundsLockedForDispute = false,
    this.dispute,
    this.canMarkCompleted = true,
    this.hasOpenDispute = false,
    this.disputeDetails,
    this.acceptedAt,
    this.disputeWindowEnd,
    this.canDispute = false,
    this.completionType,
  });

  // getById omits the item name/notes/attachments that the list row carries,
  // so keep the richer values when the detail call replaces this deal
  static String? _normaliseWantTo(dynamic raw) {
    final v = '${raw ?? ''}'.toUpperCase();
    if (v.isEmpty) return null;
    if (v == 'BUYITEM' || v == 'BUY' || v == 'BUY_AND_DELIVER') {
      return 'BUY_AND_DELIVER';
    }
    if (v == 'DELIVERITEMS' || v == 'SEND') return 'SEND';
    return v;
  }

  /// "Buy for me and deliver" / "Deliver ready items", or null when unknown.
  String? get wantToLabel => switch (wantTo) {
        'BUY_AND_DELIVER' => 'buy_for_me_and_deliver'.tr,
        'SEND' => 'deliver_ready_item'.tr,
        _ => null,
      };

  Deal withItemDetailsFrom(Deal other) => Deal(
        id: id,
        refId: refId,
        type: type,
        location: location,
        fromCountry: fromCountry,
        toCountry: toCountry,
        date: date,
        weight: weight,
        profitAmount: profitAmount,
        status: status,
        counterpart: counterpart,
        isSender: isSender,
        isTraveler: isTraveler,
        paymentMethod: paymentMethod,
        receiverName: receiverName,
        receiverPhone: receiverPhone,
        attachUrl: attachUrl,
        attachUrls: attachUrls.isNotEmpty ? attachUrls : other.attachUrls,
        itemName: itemName ?? other.itemName,
        notes: notes ?? other.notes,
        itemLink: itemLink ?? other.itemLink,
        wantTo: wantTo ?? other.wantTo,
        cancelReason: cancelReason,
        sdRequired: sdRequired,
        itemEstimatedCost: itemEstimatedCost,
        travelerGuaranteeHeld: travelerGuaranteeHeld,
        senderFundsHeld: senderFundsHeld,
        countdownSeconds: countdownSeconds,
        tripDate: tripDate,
        arrivalDate: arrivalDate ?? other.arrivalDate,
        arrivalAt: arrivalAt ?? other.arrivalAt,
        autoCompleteAt: autoCompleteAt ?? other.autoCompleteAt,
        fundsLockedForDispute: fundsLockedForDispute,
        dispute: dispute ?? other.dispute,
        canMarkCompleted: canMarkCompleted,
        hasOpenDispute: hasOpenDispute,
        disputeDetails: disputeDetails,
        acceptedAt: acceptedAt ?? other.acceptedAt,
        disputeWindowEnd: disputeWindowEnd ?? other.disputeWindowEnd,
        canDispute: canDispute,
        completionType: completionType ?? other.completionType,
      );

  // Rows from /deals/getAllDeals — a trimmed shape; the same endpoint also
  // returns the user's own posts, which carry flag "POST" instead of "DEAL".
  factory Deal.fromListJson(Map<String, dynamic> json) => Deal(
        id: json['id'] ?? 0,
        refId: '',
        type: '${json['postType'] ?? json['type'] ?? ''}'.toUpperCase() == 'TRIP'
            ? PostType.trip
            : PostType.deliver,
        location: json['location'] == 'LOCAL' ? PostLocation.local : PostLocation.international,
        fromCountry: (json['from'] ?? '').toString(),
        toCountry: (json['to'] ?? '').toString(),
        date: _parseDate(json['beforeDate']),
        weight: 0,
        profitAmount: _num(json['profit']),
        status: _status(json['status']),
        counterpart: const PostUser(name: ''),
        isSender: _hasRole(json, 'SENDER', 'isSender'),
        isTraveler: _hasRole(json, 'TRAVELER', 'isTraveler'),
        paymentMethod: json['paymentMethod'] ?? '',
        countdownSeconds: json['countdownSeconds'],
        arrivalDate: _nullableDate(json['arrivalDate']),
        arrivalAt: _arrivalAt(json),
        autoCompleteAt: _autoCompleteAt(json),
        fundsLockedForDispute: json['fundsLockedForDispute'] ?? false,
        hasOpenDispute: json['hasOpenDispute'] == true,
        cancelReason: json['cancelReason'],
        dispute: _listDispute(json),
        acceptedAt: _nullableDate(json['acceptedAt'] ?? json['accepted_at']),
        disputeWindowEnd: _nullableDate(json['disputeWindowEnd']),
        canDispute: json['canDispute'] == true,
        completionType: json['completionType']?.toString(),
      );

  /// List rows carry the dispute at the root (disputeStatus, disputeReason…);
  /// fold it into the same shape the detail screen reads.
  static Map<String, dynamic>? _listDispute(Map<String, dynamic> json) {
    if (json['hasDispute'] != true && json['isDisputed'] != true) return null;
    return {
      'id': json['disputeId'],
      'status': json['disputeStatus'],
      'statusLabel': json['disputeStatusLabel'],
      'reasonLabel': json['disputeReason'],
      'description': json['disputeDescription'],
      'decisionLabel': json['disputeDecisionLabel'] ?? json['disputeAdminDecision'],
      'resolutionNotes': json['disputeResolutionNotes'],
      'resolvedAt': json['disputeResolvedAt'],
      'attachments': json['disputeAttachments'],
    };
  }

  // Full detail from /deals/getById/{id}
  /// The API now nests everything the sender filled in under
  /// `agreementDetails`; older payloads keep the same keys at the top level,
  /// so read the block first and fall back to the flat shape.
  static Map<String, dynamic> _agreement(Map<String, dynamic> json) {
    final a = json['agreementDetails'];
    return a is Map ? {...json, ...Map<String, dynamic>.from(a)} : json;
  }

  /// `userRole` states the role outright ("SENDER" / "TRAVELER"); the boolean
  /// flags say the same thing. Either will do — older payloads carry neither,
  /// and those fall back to false, which is what the list rows already assumed.
  static bool _hasRole(Map<String, dynamic> json, String role, String flag) {
    if (json[flag] is bool) return json[flag] as bool;
    return '${json['userRole'] ?? ''}'.toUpperCase() == role;
  }

  factory Deal.fromJson(Map<String, dynamic> rawJson) {
    // agreementDetails wins where present — it is the sender's filled-in form
    final json = _agreement(rawJson);
    final isTraveler = _hasRole(json, 'TRAVELER', 'isTraveler');
    // whoever is on the other side of the agreement — the id matters as much as
    // the name, it's what opens the chat (getChatDetails/{receiver_id})
    final otherName =
        (isTraveler ? json['senderName'] : json['travelerName'])?.toString() ?? '';
    final otherId = isTraveler ? json['senderId'] : json['travelerId'];

    return Deal(
      id: json['id'] ?? 0,
      refId: (json['referenceId'] ?? json['id'] ?? '').toString(),
      type: json['type'] == 'TRIP' ? PostType.trip : PostType.deliver,
      location: json['location'] == 'LOCAL' ? PostLocation.local : PostLocation.international,
      fromCountry: (json['from'] ?? '').toString(),
      toCountry: (json['to'] ?? '').toString(),
      date: _parseDate(json['beforeDate']),
      weight: _num(json['weight']) ?? 0,
      profitAmount: _num(json['cost']),
      status: _status(json['status']),
      counterpart: PostUser(
        id: otherId is int ? otherId : int.tryParse('$otherId') ?? 0,
        name: otherName,
        // Deal detail carries the other party's badges directly
        isTransporter: (json['isApprovedTransporter'] == true) ||
            (json['transporterBadge'] == true),
      ),
      isSender: _hasRole(json, 'SENDER', 'isSender'),
      isTraveler: isTraveler,
      paymentMethod: json['paymentMethod'] ?? '',
      receiverName: json['receiverName'],
      receiverPhone: json['receiverPhone'],
      attachUrl: fixMediaUrl(json['attachLink'] ?? json['attachment']?['url']),
      attachUrls: _attachUrls(json['attachments']),
      itemName: json['itemName'],
      notes: json['notes'] ?? json['itemDescription'],
      itemLink: json['itemLink'],
      // BUYITEM and BUY_AND_DELIVER mean the same thing across endpoints
      wantTo: _normaliseWantTo(
          json['deliveryType'] ?? json['wantTo'] ?? json['dealType']),
      cancelReason: json['cancelReason'],
      sdRequired: json['sdRequired'] ?? false,
      itemEstimatedCost: _num(json['itemEstimatedCost'] ??
          json['itemValue'] ??
          json['itemPrice']),
      travelerGuaranteeHeld: json['travelerGuaranteeHeld'] ?? false,
      senderFundsHeld: json['senderFundsHeld'] ?? false,
      countdownSeconds: json['countdownSeconds'],
      tripDate: _nullableDate(json['tripDate']),
      arrivalDate: _nullableDate(json['arrivalDate']),
      arrivalAt: _arrivalAt(json),
      autoCompleteAt: _autoCompleteAt(json),
      fundsLockedForDispute: json['isLockedByDoubleDispute'] ?? false,
      dispute: json['dispute'] is Map
          ? Map<String, dynamic>.from(json['dispute'])
          : null,
      // server explicitly tells the app whether the button should show
      canMarkCompleted: json['canMarkCompleted'] ?? true,
      hasOpenDispute: json['hasOpenDispute'] ?? false,
      disputeDetails: json['disputeDetails'] is Map
          ? Map<String, dynamic>.from(json['disputeDetails'])
          : null,
      acceptedAt: _nullableDate(json['acceptedAt'] ?? json['accepted_at']),
      disputeWindowEnd: _nullableDate(json['disputeWindowEnd']),
      canDispute: json['canDispute'] == true,
      completionType: json['completionType']?.toString(),
    );
  }

  static const paymentWindow = Duration(hours: 24);
  static const arrivalWindow = Duration(hours: 48);

  /// Online deal accepted but not paid yet — the sender has 24h from
  /// acceptance before the server auto-cancels it. Null when not running.
  /// Only while still running — a deadline already behind us means the server
  /// should have cancelled the deal; a frozen 00:00:00 helps nobody.
  DateTime? get paymentDeadline {
    if (status != DealStatus.accepted ||
        paymentMethod.toUpperCase() != 'STRIPE' ||
        senderFundsHeld ||
        acceptedAt == null) {
      return null;
    }
    final end = acceptedAt!.add(paymentWindow);
    return end.isAfter(DateTime.now()) ? end : null;
  }

  /// The scheduled arrival — exact date + time when known, else the day.
  DateTime? get scheduledArrival => arrivalAt ?? arrivalDate;

  /// End of the 48h window: the server's own deadline wins, otherwise 48h
  /// from the scheduled arrival (never from the deal's creation).
  DateTime? get _autoCompleteDeadline =>
      autoCompleteAt ?? scheduledArrival?.add(arrivalWindow);

  /// From the scheduled arrival, 48h to scan the QR, confirm or dispute
  /// before the server auto-completes. Applies to online and COD deals and
  /// stops once a dispute is open. Null when not running.
  DateTime? get arrivalWindowEnd {
    if (status != DealStatus.outgoing || disputeActive) return null;
    final end = _autoCompleteDeadline;
    if (end == null) return null;
    final now = DateTime.now();
    if (now.isBefore(end.subtract(arrivalWindow))) return null;
    return end.isAfter(now) ? end : null;
  }

  /// Ongoing deal still before its scheduled arrival: when the 48h window
  /// will open. Null once it has started (or doesn't apply).
  DateTime? get arrivalWindowStartsAt {
    if (status != DealStatus.outgoing || disputeActive) return null;
    final end = _autoCompleteDeadline;
    if (end == null) return null;
    final start = end.subtract(arrivalWindow);
    return DateTime.now().isBefore(start) ? start : null;
  }

  /// Post-completion dispute window still counting. Null when not running.
  DateTime? get disputeWindowEndsAt =>
      status == DealStatus.completed &&
              canDispute &&
              !hasDisputeRecord &&
              disputeWindowEnd != null &&
              disputeWindowEnd!.isAfter(DateTime.now())
          ? disputeWindowEnd
          : null;

  bool get isAutoCompleted =>
      (completionType ?? '').toUpperCase().startsWith('AUTO_COMPLETED');

  /// Cancelled by the server because the 24h payment window ran out.
  bool get isAutoCancelledUnpaid {
    final r = (cancelReason ?? '').toLowerCase();
    return r.contains('auto-cancel') || r.contains('auto_cancel') ||
        r.contains('within 24h') || r.contains('24 heures');
  }

  bool get isLocal => location == PostLocation.local;

  /// Whatever dispute record the server sent, richest shape first.
  Map<String, dynamic>? get disputeInfo => disputeDetails ?? dispute;

  /// A dispute was filed on this deal at some point — its report stays
  /// reachable whatever the deal status is now.
  bool get hasDisputeRecord =>
      status == DealStatus.disputes || hasOpenDispute || disputeInfo != null;

  /// A dispute is still being processed. While true the deal can't be marked
  /// completed or disputed again — only the dispute resolution closes it.
  bool get disputeActive {
    if (status == DealStatus.disputes || hasOpenDispute) return true;
    final info = disputeInfo;
    if (info == null) return false;
    // raw status / isResolved only — the labels are translated
    if (info['isResolved'] == true) return false;
    final s = '${info['status'] ?? ''}'.toUpperCase();
    return !const ['RESOLV', 'CLOS', 'REJECT', 'CANCEL', 'DISMISS']
        .any(s.contains);
  }

  String get profitLabel => profitAmount == null ? '—' : _money(profitAmount!);
  String get depositLabel =>
      itemEstimatedCost == null ? '—' : _money(itemEstimatedCost!);

  // The deal is always created by the sender (website: canRequestDeal is
  // sender-only), so the proposer is simply the sender. Accepting/rejecting a
  // pending deal is the traveler's call.
  bool get isProposer => isSender;

  // the receiver scans this at handover — it opens the website's public
  // confirmation page for this deal (getByReferenceId under the hood)
  String get confirmationLink => '${ApiConstants.webBaseUrl}/deal-details/$refId';

  // the traveler must put up a card hold before the item moves
  bool get needsGuarantee =>
      sdRequired && isTraveler && !travelerGuaranteeHeld && status == DealStatus.accepted;

  // the sender funds the deal once the traveler has accepted
  bool get needsPayment =>
      isSender &&
      !senderFundsHeld &&
      status == DealStatus.accepted &&
      paymentMethod.toUpperCase() == 'STRIPE';

  // COD deals need no escrow, so they count as already paid; STRIPE deals wait
  // for the sender's hold before the traveler can move things on
  bool get senderHasPaid => senderFundsHeld || paymentMethod.toUpperCase() != 'STRIPE';

  // the sender shares the receiver's QR the whole time the deal is live —
  // website: shown unless cancelled/rejected/completed (so incl. disputed)
  bool get showsReceiverQr =>
      isSender &&
      refId.isNotEmpty &&
      status != DealStatus.cancelled &&
      status != DealStatus.completed;

  // at ACCEPTED the traveler can't start until the sender's payment clears
  bool get travelerWaitingOnPayment =>
      isTraveler && status == DealStatus.accepted && !senderHasPaid;

  // ...and their own guarantee (if required) is in place
  bool get travelerCanStart =>
      isTraveler &&
      status == DealStatus.accepted &&
      senderHasPaid &&
      (!sdRequired || travelerGuaranteeHeld);

  String get paymentLabel => switch (paymentMethod.toUpperCase()) {
        'STRIPE' => 'pay_online'.tr,
        'COD' || 'CASH_ON_DELIVERY' => 'cash_on_delivery'.tr,
        '' => '—',
        _ => paymentMethod,
      };

  // reason codes read better as the label the user originally picked
  String? get cancelReasonLabel {
    if (cancelReason == null || cancelReason!.isEmpty) return null;
    if (isAutoCancelledUnpaid) return 'auto_cancelled_unpaid_24h'.tr;
    for (final r in CancelReason.values) {
      if (r.code == cancelReason) return r.label;
    }
    return cancelReason;
  }

  static String _money(double v) => '\$${v.toStringAsFixed(2)}';

  static double? _num(dynamic v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

  // the API says OUTGOING in filters but has also sent ONGOING on rows
  static DealStatus _status(dynamic raw) => switch (raw?.toString().toUpperCase()) {
        'ACCEPTED' => DealStatus.accepted,
        'OUTGOING' || 'ONGOING' => DealStatus.outgoing,
        'COMPLETED' => DealStatus.completed,
        'CANCELED' || 'CANCELLED' || 'REJECTED' => DealStatus.cancelled,
        'DISPUTES' || 'DISPUTE' || 'DISPUTED' => DealStatus.disputes,
        _ => DealStatus.pending,
      };

  static DateTime? _nullableDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw) ?? _parseUsDate(raw);
  }

  /// Exact arrival moment: an explicit field, or arrivalDate + arrivalTime.
  static DateTime? _arrivalAt(Map<String, dynamic> json) {
    final exact = _nullableDate(
        json['arrivalAt'] ?? json['arrivalDateTime'] ?? json['arrival_at']);
    if (exact != null) return exact;
    final day = _nullableDate(json['arrivalDate']);
    final time = '${json['arrivalTime'] ?? ''}'.split(':');
    if (day == null || time.length < 2) return null;
    final h = int.tryParse(time[0]), m = int.tryParse(time[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  static DateTime? _autoCompleteAt(Map<String, dynamic> json) => _nullableDate(
      json['autoCompleteAt'] ?? json['autoCompletesAt'] ?? json['arrivalWindowEnd']);

  /// "10/05/2026 06:00 PM" — the API's display format for dates.
  static DateTime? _parseUsDate(String raw) {
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{2})\s*([AaPp][Mm])?)?')
        .firstMatch(raw.trim());
    if (m == null) return null;
    var hour = int.tryParse(m.group(4) ?? '') ?? 0;
    final ampm = m.group(6)?.toUpperCase();
    if (ampm == 'PM' && hour < 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    return DateTime(int.parse(m.group(3)!), int.parse(m.group(1)!),
        int.parse(m.group(2)!), hour, int.tryParse(m.group(5) ?? '') ?? 0);
  }

  // dates arrive as "08/01/2026 06:00 AM" or ISO-8601
  static DateTime _parseDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return DateTime.now();
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;
    try {
      final d = raw.split(' ')[0].split('/');
      return DateTime(int.parse(d[2]), int.parse(d[0]), int.parse(d[1]));
    } catch (_) {
      return DateTime.now();
    }
  }
}

extension DealStatusX on DealStatus {
  String get label => switch (this) {
        DealStatus.pending => 'deal_status_pending'.tr,
        DealStatus.accepted => 'deal_status_accepted'.tr,
        DealStatus.outgoing => 'deal_status_ongoing'.tr,
        DealStatus.completed => 'deal_status_completed'.tr,
        DealStatus.cancelled => 'deal_status_cancelled'.tr,
        DealStatus.disputes => 'deal_status_dispute'.tr,
      };

  // what /deals/getAllDeals expects in ?status=
  String get apiValue => switch (this) {
        DealStatus.pending => 'PENDING',
        DealStatus.accepted => 'ACCEPTED',
        DealStatus.outgoing => 'OUTGOING',
        DealStatus.completed => 'COMPLETED',
        DealStatus.cancelled => 'CANCELED',
        DealStatus.disputes => 'DISPUTES',
      };

  // (background, foreground) — tints mirror the web deals list
  (Color, Color) get colors => switch (this) {
        DealStatus.pending => (const Color(0xFFFEF9C3), const Color(0xFF854D0E)),
        DealStatus.accepted => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
        DealStatus.outgoing => (const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
        DealStatus.completed => (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
        DealStatus.cancelled => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
        DealStatus.disputes => (const Color(0xFFFFF1F2), const Color(0xFFBE123C)),
      };
}
