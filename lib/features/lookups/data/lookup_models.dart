import '../../../core/utils/media_url.dart';

class Country {
  final int id;
  final String name;
  final String iso2;
  final String phoneCode; // e.g. "216" — drives the receiver phone prefix
  final String emoji;

  const Country({
    required this.id,
    required this.name,
    required this.iso2,
    this.phoneCode = '',
    this.emoji = '',
  });

  factory Country.fromJson(Map<String, dynamic> json) => Country(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        iso2: json['iso2'] ?? '',
        phoneCode: '${json['phonecode'] ?? json['phoneCode'] ?? ''}',
        emoji: json['emoji'] ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'iso2': iso2, 'phonecode': phoneCode, 'emoji': emoji};

  @override
  bool operator ==(Object other) => other is Country && other.id == id;

  @override
  int get hashCode => id;
}

class City {
  final int id;
  final String name;

  const City({required this.id, required this.name});

  factory City.fromJson(Map<String, dynamic> json) =>
      City(id: json['id'] ?? 0, name: json['name'] ?? '');

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class Category {
  final int id;
  final String title;

  const Category({required this.id, required this.title});

  factory Category.fromJson(Map<String, dynamic> json) =>
      Category(id: json['id'] ?? 0, title: json['title'] ?? json['name'] ?? '');

  Map<String, dynamic> toJson() => {'id': id, 'title': title};
}

class HomeBanner {
  final int id;
  final String? title;
  final String? linkUrl;
  final String? imageUrl;

  const HomeBanner({required this.id, this.title, this.linkUrl, this.imageUrl});

  factory HomeBanner.fromJson(Map<String, dynamic> json) => HomeBanner(
        id: json['id'] ?? 0,
        title: json['title'],
        linkUrl: json['linkUrl'],
        // phones get the mobile crop; fall back to desktop if it's missing
        imageUrl: fixMediaUrl(
            json['mobileImage']?['url'] ?? json['desktopImage']?['url']),
      );
}
