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

  const PostUser({
    this.id = 0,
    required this.name,
    this.verified = false,
    this.rating = 0,
    this.avatarUrl,
    this.isTransporter = false,
    this.isRecommendedTransporter = false,
  });

  factory PostUser.fromJson(Map<String, dynamic> json) => PostUser(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        verified: json['identityVerified'] ?? false,
        rating: Post._num(json['rate']),
        avatarUrl: json['imageUrl'] ?? json['avatarUrl'],
        // badge logic per the API doc: approved = plain badge, an active paid
        // subscription upgrades it to the recommended one
        isTransporter: (json['isTransporter'] ?? false) &&
            (json['transporterVerificationStatus'] ?? 'approved') == 'approved',
        isRecommendedTransporter: (json['isFeaturedTransporter'] ?? false) &&
            json['transporterVisibilityStatus'] == 'active',
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
    this.status,
    required this.user,
    this.recommended = false,
  });

  factory Post.fromJson(Map<String, dynamic> json, {bool recommended = false}) {
    return Post(
      id: json['id'] ?? 0,
      type: json['type'] == 'TRIP' ? PostType.trip : PostType.deliver,
      location: json['location'] == 'LOCAL' ? PostLocation.local : PostLocation.international,
      wantTo: json['wantTo'] == 'BUY_AND_DELIVER' ? WantTo.buyAndDeliver : WantTo.send,
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
      date: _parseDate(json['beforeDate']),
      weight: _num(json['weight']),
      remainingWeight: json['remainingWeight'] == null ? null : _num(json['remainingWeight']),
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
      status: json['status'],
      user: PostUser.fromJson(Map<String, dynamic>.from(json['user'] ?? {})),
      recommended: recommended,
    );
  }

  // "my posts" rows come back stripped down: {id, location, from, to,
  // beforeDate, status: TRIP|DELIVER, flag: POST}
  factory Post.fromOwnPostJson(Map<String, dynamic> json) => Post(
        id: json['id'] ?? 0,
        type: json['status'] == 'TRIP' ? PostType.trip : PostType.deliver,
        location:
            json['location'] == 'LOCAL' ? PostLocation.local : PostLocation.international,
        fromCountry: _name(json['from']),
        toCountry: _name(json['to']),
        date: _parseDate(json['beforeDate']),
        dateLabel: _dateLabel(json['beforeDate']),
        weight: _num(json['weight']), // arrives as a string ("20")
        remainingWeight:
            json['remainingWeight'] == null ? null : _num(json['remainingWeight']),
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

  /// Compact for cards: "10 / 20 kg" once partly booked, otherwise "20 kg".
  String get weightText => partlyBooked
      ? '${kg(availableWeight).replaceAll(' kg', '')} / ${kg(weight)}'
      : kg(weight);

  /// Roomier phrasing for the details screen.
  String get weightDetailText => partlyBooked
      ? 'weight_left_of_total'.trParams({
          'left': kg(availableWeight),
          'total': kg(weight),
        })
      : kg(weight);

  /// All categories on a request, or the single one older payloads send.
  String get categoriesText =>
      categories.isNotEmpty ? categories.join(', ') : (category ?? '');

  String? get _label {
    final raw = dateLabel;
    if (raw == null) return null;
    final probe = raw.toLowerCase();
    return probe.contains('no specific date') || probe.contains('pas de date')
        ? 'no_specific_date_time'.tr
        : raw;
  }

  // numbers sometimes arrive as strings ("5") — never trust the type
  static double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

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

  // the API returns a phrase like "No specific date/time" when a trip was
  // posted without one — keep it so the UI doesn't invent a date
  static String? _dateLabel(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return RegExp(r'^\d{1,2}/\d{1,2}/\d{4}').hasMatch(raw) ? null : raw;
  }

  // "08/01/2026 12:00 AM" — MM/dd/yyyy with a 12h clock
  static DateTime _parseDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return DateTime.now();
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
