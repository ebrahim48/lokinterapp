import '../../../../core/utils/media_url.dart';
import '../../../../core/utils/format.dart';
import 'package:get/get.dart';

enum PostType { trip, deliver }

enum PostLocation { local, international }

// what the sender wants on a delivery request
enum WantTo { send, buyAndDeliver }

class PostUser {
  final int id;
  final String name;
  final bool verified;
  final double rating;
  final String? avatarUrl;
  final bool isTransporter; // approved transporter
  // paid premium placement — shows the gold badge instead of the plain one
  final bool isRecommendedTransporter;
  /// Increase-visibility state from the payload: true when it is running,
  /// false when it is off/expired/disabled by admin, null when the row
  /// doesn't say.
  final bool? visibilityActive;

  const PostUser({
    this.id = 0,
    required this.name,
    this.verified = false,
    this.rating = 0,
    this.avatarUrl,
    this.isTransporter = false,
    this.isRecommendedTransporter = false,
    this.visibilityActive,
  });

  factory PostUser.fromJson(Map<String, dynamic> json) => PostUser(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        verified: json['identityVerified'] ?? false,
        rating: Post._num(json['rate']),
        avatarUrl: avatarUrlFrom(json),
        // badge logic per spec: use isApprovedTransporter or transporterBadge
        // (both explicit boolean flags). Do NOT gate on isTransporter alone —
        // that field is set before admin approval on older payloads.
        isTransporter: (json['isApprovedTransporter'] == true) ||
            (json['transporterBadge'] == true) ||
            ((json['isTransporter'] ?? false) &&
                (json['transporterVerificationStatus'] ?? 'approved') == 'approved'),
        isRecommendedTransporter: (json['isFeaturedTransporter'] ?? false) &&
            json['transporterVisibilityStatus'] == 'active',
        visibilityActive: visibilityState(json),
      );
}

class Post {
  final int id;
  final PostType type;
  final PostLocation location;
  final WantTo wantTo;
  final String? title; // item name for deliver requests
  final String? description; // request item description
  final String fromCountry;
  final String toCountry;
  final String? fromIso; // ISO2 for the flag widget
  final String? toIso;
  final String? fromCity;
  final String? toCity;
  final DateTime date; // trip date, or "before" date for requests
  final double weight; // kg
  final double? remainingWeight; // remaining kg on a trip
  final String? profit; // already-formatted, e.g. "TND 50.000"
  final String? imageUrl;
  final String? category;
  final int? categoryId;
  final String? airline;
  final String? pickupLocation;
  final String? dropoffLocation;
  // exact map pins for the two points — null when the poster typed an
  // address only (older posts, the website); never guessed
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  // Google Maps search links the API builds for the two locations
  final String? pickupLocationLink;
  final String? dropoffLocationLink;
  // server's own capacity text, e.g. "10 kg left"
  final String? remainingWeightDisplay;
  // past its date / every kg already booked — no longer an active post
  final bool isExpired;
  final bool isFullyConsumed;
  final String? status;
  // free-text notes: deliveryPoints on a request, pickupPoints on a trip
  final String? notes;
  // the API's own label for the date — may read "No specific date/time"
  final String? dateLabel;
  // trips can rule out several categories at once
  final List<String> rejectedCategories;
  // a delivery request can carry several categories
  final List<String> categories;
  // currency the profit is quoted in; the platform settles in USD
  final String currency;
  final PostUser user;
  final bool recommended;
  /// The API says outright whether the signed-in user created this post; when
  /// it doesn't, comparing `user.id` still works.
  final bool? isPostCreator;
  /// When the post was created — an "Available upon request" post only lives
  /// for that day.
  final DateTime? createdAt;
  /// Visibility flags some endpoints put on the post row instead of the user.
  final bool? visibilityActive;

  const Post({
    this.dateLabel,
    this.notes,
    this.rejectedCategories = const [],
    this.categories = const [],
    this.currency = 'USD',
    this.id = 0,
    required this.type,
    required this.location,
    this.wantTo = WantTo.send,
    this.title,
    this.description,
    required this.fromCountry,
    required this.toCountry,
    this.fromIso,
    this.toIso,
    this.fromCity,
    this.toCity,
    required this.date,
    required this.weight,
    this.remainingWeight,
    this.profit,
    this.imageUrl,
    this.category,
    this.categoryId,
    this.airline,
    this.pickupLocation,
    this.dropoffLocation,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.pickupLocationLink,
    this.dropoffLocationLink,
    this.remainingWeightDisplay,
    this.isExpired = false,
    this.isFullyConsumed = false,
    this.status,
    required this.user,
    this.recommended = false,
    this.isPostCreator,
    this.createdAt,
    this.visibilityActive,
  });

  /// True when this is my own post. Prefers the server's flag.
  bool mine(int? myId) =>
      isPostCreator ?? (user.id != 0 && myId != null && user.id == myId);

  factory Post.fromJson(Map<String, dynamic> json, {bool recommended = false}) {
    return Post(
      id: json['id'] ?? 0,
      type: json['type'] == 'TRIP' ? PostType.trip : PostType.deliver,
      location: json['location'] == 'LOCAL' ? PostLocation.local : PostLocation.international,
      wantTo: _wantTo(json['wantTo'] ?? json['dealType']),
      title: json['title'],
      // the API persists the request's item description in deliveryPoints
      // (website convention); older payloads may still use description
      description: json['description'] ?? json['deliveryPoints'],
      fromCountry: _name(json['fromCountry']),
      toCountry: _name(json['toCountry']),
      fromIso: _iso(json['fromCountry']),
      toIso: _iso(json['toCountry']),
      fromCity: _nullableName(json['fromCity']),
      toCity: _nullableName(json['toCity']),
      // rawBeforeDate is the wall-clock time exactly as the poster picked it
      date: _parseDate(json['rawBeforeDate'] ?? json['beforeDate']),
      weight: _num(json['weight']),
      remainingWeight: _remaining(json),
      // the API returns the offered profit as `travelerProfit`; `profit` is the
      // older pre-formatted string some endpoints still send
      profit: json['travelerProfit'] != null
          ? '${json['travelerProfit']}'
          : json['profit']?.toString(),
      imageUrl: fixMediaUrl(json['attachUrl'] ?? json['imageUrl'] ?? json['attachFile']?['url']),
      category: json['categoryTitle'],
      notes: json['pickupPoints'] ?? json['deliveryPoints'],
      dateLabel: _dateLabel(json['beforeDate']),
      rejectedCategories: (json['rejectedCategoriesTitles'] as List? ?? const [])
          .map((e) => '$e')
          .toList(),
      currency: json['currency'] ?? 'USD',
      categories: (json['categoryTitles'] as List? ??
              (json['categoryTitle'] == null ? const [] : [json['categoryTitle']]))
          .map((e) => '$e')
          .toList(),
      categoryId: json['categoryId'],
      airline: json['airLine'],
      pickupLocation: json['pickupLocation'],
      dropoffLocation: json['dropoffLocation'],
      pickupLat: _coord(json['pickupLat'] ?? json['pickup_lat']),
      pickupLng: _coord(json['pickupLng'] ?? json['pickup_lng']),
      dropoffLat: _coord(json['dropoffLat'] ?? json['dropoff_lat']),
      dropoffLng: _coord(json['dropoffLng'] ?? json['dropoff_lng']),
      pickupLocationLink: _link(json['pickupLocationLink']),
      dropoffLocationLink: _link(json['dropoffLocationLink']),
      remainingWeightDisplay: _text(json['remainingWeightDisplay']),
      isExpired: json['isExpired'] == true,
      isFullyConsumed: json['isFullyConsumed'] == true,
      status: json['status'],
      user: PostUser.fromJson(Map<String, dynamic>.from(json['user'] ?? {})),
      isPostCreator: json['isPostCreator'] is bool ? json['isPostCreator'] : null,
      recommended: recommended,
      createdAt: _created(json),
      visibilityActive: visibilityState(json),
    );
  }

  // "my posts" rows come back stripped down: {id, location, from, to,
  // beforeDate, status: TRIP|DELIVER, flag: POST}
  factory Post.fromOwnPostJson(Map<String, dynamic> json) => Post(
        // this endpoint only ever returns the caller's own rows
        isPostCreator: true,
        id: json['id'] ?? 0,
        type: json['status'] == 'TRIP' ? PostType.trip : PostType.deliver,
        location:
            json['location'] == 'LOCAL' ? PostLocation.local : PostLocation.international,
        fromCountry: _name(json['from']),
        toCountry: _name(json['to']),
        date: _parseDate(json['rawBeforeDate'] ?? json['beforeDate']),
        dateLabel: _dateLabel(json['beforeDate']),
        weight: _num(json['weight']), // arrives as a string ("20")
        remainingWeight: _remaining(json),
        remainingWeightDisplay: _text(json['remainingWeightDisplay']),
        isExpired: json['isExpired'] == true,
        isFullyConsumed: json['isFullyConsumed'] == true,
        pickupLocation: json['pickupLocation'],
        dropoffLocation: json['dropoffLocation'],
        pickupLat: _coord(json['pickupLat'] ?? json['pickup_lat']),
        pickupLng: _coord(json['pickupLng'] ?? json['pickup_lng']),
        dropoffLat: _coord(json['dropoffLat'] ?? json['dropoff_lat']),
        dropoffLng: _coord(json['dropoffLng'] ?? json['dropoff_lng']),
        pickupLocationLink: _link(json['pickupLocationLink']),
        dropoffLocationLink: _link(json['dropoffLocationLink']),
        // the my-posts endpoint carries the full row now, so own posts show the
        // same information as any other result card
        wantTo: _wantTo(json['wantTo'] ?? json['dealType']),
        title: json['title'] ?? json['itemName'],
        description: json['itemDescription'] ?? json['notes'],
        notes: json['notes'] ?? json['itemDescription'],
        profit: json['profit'] != null
            ? '${json['profit']}'
            : (json['reward'] != null ? '${json['reward']}' : null),
        currency: json['currency'] ?? 'USD',
        createdAt: _created(json),
        imageUrl: fixMediaUrl(json['attachLink'] ??
            (json['attachment'] is Map ? json['attachment']['url'] : null)),
        user: const PostUser(name: ''),
      );

  bool get isTrip => type == PostType.trip;
  bool get isLocal => location == PostLocation.local;
  String get from => fromCity ?? fromCountry;
  String get to => toCity ?? toCountry;
  String? get flagIso => fromIso; // local posts fly their country's flag
  // what to print for the date: the API's phrase when there isn't a real one.
  // The two endpoints word it differently, so any "no date" variant is shown
  // with our own localized copy.
  /// Local posts are time-sensitive, so they show the clock too.
  String get dateText =>
      _label ?? (isLocal ? shortDateTime(date) : shortDate(date));
  String get shortDateText => _label ?? (isLocal ? shortDateTime(date) : dayMonth(date));

  /// Offered profit with its currency, e.g. "USD 50". Null when none was set.
  String? get profitText {
    final p = profit;
    if (p == null || p.isEmpty) return null;
    // already formatted by an older endpoint ("TND 50.000")
    if (RegExp(r'[A-Za-z]').hasMatch(p)) return p;
    final n = double.tryParse(p);
    return n == null ? p : '$currency ${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2)}';
  }

  /// True once part of the capacity has been booked by a confirmed deal.
  bool get partlyBooked {
    final left = remainingWeight;
    return left != null && left < weight;
  }

  /// What's actually still available — the number that matters to the person
  /// reading the post.
  double get availableWeight => remainingWeight ?? weight;

  /// A trip shows what's still free ("10 kg left"); a request shows the kg
  /// it asks for until part of it is booked.
  String get weightText {
    if (!isTrip && !partlyBooked) return kg(weight);
    // the API's own phrase is English-only, so localize ours in French
    final server = remainingWeightDisplay;
    if (server != null && (Get.locale?.languageCode ?? 'en') != 'fr') {
      return server;
    }
    return 'kg_left'.trParams({'kg': kg(availableWeight)});
  }

  /// Same on the details screen.
  String get weightDetailText => weightText;

  /// Not active any more: past its date, or every kg already booked.
  bool get isInactive =>
      isExpired ||
      isFullyConsumed ||
      isPastDate ||
      isStaleNoDate ||
      (isTrip && remainingWeight != null && remainingWeight! <= 0);

  /// The scheduled moment has passed. A post stays live until its exact time;
  /// a date with no clock (00:00) counts as the whole day. "Available upon
  /// request" posts have no date — the server's isExpired covers those.
  bool get isPastDate {
    if (_label != null) return false;
    final until = date.hour == 0 && date.minute == 0
        ? DateTime(date.year, date.month, date.day).add(const Duration(days: 1))
        : date;
    return !until.isAfter(DateTime.now());
  }

  /// "Available upon request" posts are only good for the day they were
  /// posted. The server's isExpired should already say so; this catches lists
  /// that don't apply it (recommended travelers).
  bool get isStaleNoDate {
    final c = createdAt;
    if (_label == null || c == null) return false;
    final now = DateTime.now();
    return DateTime(c.year, c.month, c.day).isBefore(DateTime(now.year, now.month, now.day));
  }

  /// Whether a recommended-travelers row may be shown: still active, and the
  /// traveler's increase visibility isn't off. Rows that don't carry a
  /// visibility flag are left to the server's own filter.
  bool get showInRecommended {
    if (isInactive) return false;
    return visibilityActive != false && user.visibilityActive != false;
  }

  /// All categories on a request, or the single one older payloads send.
  String get categoriesText =>
      categories.isNotEmpty ? categories.join(', ') : (category ?? '');

  String? get _label {
    final raw = dateLabel;
    if (raw == null) return null;
    return isNoDateLabel(raw) ? 'no_specific_date_time'.tr : raw;
  }

  // the API uses BUY_AND_DELIVER on posts and BUYITEM on deals for the same
  // thing, so accept either rather than silently defaulting to "send"
  static WantTo _wantTo(dynamic raw) {
    final v = '${raw ?? ''}'.toUpperCase();
    return (v == 'BUY_AND_DELIVER' || v == 'BUYITEM' || v == 'BUY')
        ? WantTo.buyAndDeliver
        : WantTo.send;
  }

  // numbers sometimes arrive as strings ("5") — never trust the type
  static double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  // a coordinate, or null when absent/unparseable — unlike [_num], never 0,
  // since 0,0 would be a real (wrong) point on the map
  static double? _coord(dynamic v) {
    if (v == null) return null;
    return v is num ? v.toDouble() : double.tryParse(v.toString());
  }

  // country fields come as {id, name, iso2}; cities as {id, name}, plain
  // text, or a bare [] when unset
  static String _name(dynamic v) {
    if (v is Map) return v['name'] ?? '';
    if (v is List) return '';
    return v?.toString() ?? '';
  }

  static String? _nullableName(dynamic v) {
    final n = _name(v);
    return n.isEmpty ? null : n;
  }

  static String? _iso(dynamic v) => v is Map ? v['iso2'] : null;

  // newer payloads send availableWeight, older ones remainingWeight
  static double? _remaining(Map<String, dynamic> json) {
    final v = json['availableWeight'] ?? json['remainingWeight'];
    return v == null ? null : _num(v);
  }

  static DateTime? _created(Map<String, dynamic> json) {
    final raw = json['createdAt'] ?? json['created_at'] ?? json['postedAt'];
    return raw is String ? parseServerDate(raw) : null;
  }

  static String? _text(dynamic v) {
    final t = v?.toString().trim() ?? '';
    return t.isEmpty ? null : t;
  }

  static String? _link(dynamic v) {
    final t = _text(v);
    return t != null && t.startsWith('http') ? t : null;
  }

  // the API returns a phrase like "Available upon request" when a trip was
  // posted without a date — keep it so the UI doesn't invent one
  static String? _dateLabel(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return RegExp(r'^\d{1,4}[/-]\d{1,2}[/-]\d{1,4}').hasMatch(raw) ? null : raw;
  }

  // "08/01/2026 12:00 AM" (MM/dd/yyyy, 12h clock) or "2026-08-01 15:00".
  // Read as wall-clock time — never shifted through a timezone, so 3:00 PM
  // posted shows 3:00 PM.
  static DateTime _parseDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return DateTime.now();
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}))?').firstMatch(raw);
    if (iso != null) {
      return DateTime(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
        int.parse(iso.group(4) ?? '0'),
        int.parse(iso.group(5) ?? '0'),
      );
    }
    try {
      final parts = raw.split(' ');
      final d = parts[0].split('/');
      var hour = 0, minute = 0;
      if (parts.length >= 3) {
        final hm = parts[1].split(':');
        hour = int.parse(hm[0]) % 12;
        minute = int.parse(hm[1]);
        if (parts[2].toUpperCase() == 'PM') hour += 12;
      }
      return DateTime(int.parse(d[2]), int.parse(d[0]), int.parse(d[1]), hour, minute);
    } catch (_) {
      return DateTime.now();
    }
  }
}

/// Increase-visibility state read off a user/transporter row: true when it is
/// running, false when the row says it is off (expired, unpaid, or disabled by
/// admin), null when the row carries no visibility field at all.
bool? visibilityState(Map<String, dynamic> t) {
  const off = ['disabled', 'expired', 'inactive', 'none', 'suspended', 'revoked', 'cancelled'];
  // an admin switch-off wins over any stale "featured" flag
  if (t['visibilityEnabled'] == false ||
      t['visibilityDisabled'] == true ||
      t['isVisibilityDisabled'] == true) {
    return false;
  }
  const statusKeys = [
    'visibilityStatus',
    'transporterVisibilityStatus',
    'travelerVisibilityStatus',
  ];
  final statuses = statusKeys
      .where((k) => t[k] != null)
      .map((k) => '${t[k]}'.toLowerCase())
      .toList();
  if (statuses.any(off.contains) && !statuses.contains('active')) return false;
  if (statuses.contains('active')) return true;
  const flagKeys = [
    'visibilityActive',
    'isFeatured',
    'featuredTransporter',
    'isFeaturedTransporter',
    'isFeaturedTraveler',
    'isRecommendedTransporter',
    'isRecommendedTraveler',
    'hasActiveSubscription',
  ];
  final flags = flagKeys.where(t.containsKey).toList();
  if (flags.isEmpty) return statuses.isEmpty ? null : false;
  return flags.any((k) => t[k] == true);
}

/// Whether an API date text means "no date" — older payloads say "No specific
/// date/time", newer ones "Available upon request", in either language.
bool isNoDateLabel(String raw) {
  final probe = raw.toLowerCase();
  return probe.contains('no specific date') ||
      probe.contains('pas de date') ||
      probe.contains('available upon request') ||
      probe.contains('disponible sur demande');
}
