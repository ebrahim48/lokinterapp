import '../../../../core/utils/media_url.dart';

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
  final bool isTransporter; // registered transporter — no API flag yet

  const PostUser({
    this.id = 0,
    required this.name,
    this.verified = false,
    this.rating = 0,
    this.avatarUrl,
    this.isTransporter = false,
  });

  factory PostUser.fromJson(Map<String, dynamic> json) => PostUser(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        verified: json['identityVerified'] ?? false,
        rating: Post._num(json['rate']),
        avatarUrl: json['imageUrl'] ?? json['avatarUrl'],
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
  final String? status;
  final PostUser user;
  final bool recommended;

  const Post({
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
      description: json['description'],
      fromCountry: _name(json['fromCountry']),
      toCountry: _name(json['toCountry']),
      fromIso: _iso(json['fromCountry']),
      toIso: _iso(json['toCountry']),
      fromCity: _nullableName(json['fromCity']),
      toCity: _nullableName(json['toCity']),
      date: _parseDate(json['beforeDate']),
      weight: _num(json['weight']),
      remainingWeight: json['remainingWeight'] == null ? null : _num(json['remainingWeight']),
      profit: json['profit']?.toString(),
      imageUrl: fixMediaUrl(json['attachUrl'] ?? json['imageUrl'] ?? json['attachFile']?['url']),
      category: json['categoryTitle'],
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
        weight: 0, // not included in this shape
        user: const PostUser(name: ''),
      );

  bool get isTrip => type == PostType.trip;
  bool get isLocal => location == PostLocation.local;
  String get from => fromCity ?? fromCountry;
  String get to => toCity ?? toCountry;
  String? get flagIso => fromIso; // local posts fly their country's flag

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
