class AuthUser {
  final int id;
  final String fullName;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? country; // ISO2
  final String? imageUrl;
  final bool identityVerified;
  final int notificationsCount;
  final String? lang; // en | fr — restores the app language on cold start

  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.country,
    this.imageUrl,
    this.identityVerified = false,
    this.notificationsCount = 0,
    this.lang,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] ?? 0,
        fullName: json['fullName'] ?? json['name'] ?? '',
        email: json['email'] ?? '',
        firstName: json['firstName'],
        lastName: json['lastName'],
        phone: json['phone']?.toString(),
        country: json['country'],
        imageUrl: json['imageUrl'] ?? json['avatarUrl'],
        identityVerified: json['identityVerified'] ?? false,
        notificationsCount: json['notificationsCount'] ?? 0,
        lang: json['lang'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'country': country,
        'imageUrl': imageUrl,
        'identityVerified': identityVerified,
        'notificationsCount': notificationsCount,
        'lang': lang,
      };
}
