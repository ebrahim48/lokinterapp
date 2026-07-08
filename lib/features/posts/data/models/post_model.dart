enum PostType { trip, deliver }

enum PostLocation { local, international }

// what the sender wants on a delivery request
enum WantTo { send, buyAndDeliver }

class PostUser {
  final String name;
  final bool verified;
  final double rating;
  final String? avatarUrl;
  final bool isTransporter; // registered transporter — gets a badge

  const PostUser({
    required this.name,
    this.verified = false,
    this.rating = 0,
    this.avatarUrl,
    this.isTransporter = false,
  });
}

class Post {
  final PostType type;
  final PostLocation location;
  final WantTo wantTo;
  final String? title; // item name for deliver requests
  final String? description; // request item description
  final String fromCountry;
  final String toCountry;
  final String? fromCity;
  final String? toCity;
  final DateTime date; // trip date, or "before" date for requests
  final double weight; // kg
  final double? remainingWeight; // remaining kg on a trip
  final String? profit; // already-formatted, e.g. "TND 50.000"
  final String? imageUrl;
  final PostUser user;
  final bool recommended;

  const Post({
    required this.type,
    required this.location,
    this.wantTo = WantTo.send,
    this.title,
    this.description,
    required this.fromCountry,
    required this.toCountry,
    this.fromCity,
    this.toCity,
    required this.date,
    required this.weight,
    this.remainingWeight,
    this.profit,
    this.imageUrl,
    required this.user,
    this.recommended = false,
  });

  bool get isTrip => type == PostType.trip;
  bool get isLocal => location == PostLocation.local;
  String get from => fromCity ?? fromCountry;
  String get to => toCity ?? toCountry;
}
