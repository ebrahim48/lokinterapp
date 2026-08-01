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

  // transporter status — drives which badge (if any) the account shows
  final bool isTransporter;
  final String? transporterVerificationStatus; // pending | approved | rejected
  final bool isFeaturedTransporter;
  final String? featuredTransporterUntil;
  final String? transporterVisibilityStatus; // active | expired | none
  final String? kycStatus;

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
    this.isTransporter = false,
    this.transporterVerificationStatus,
    this.isFeaturedTransporter = false,
    this.featuredTransporterUntil,
    this.transporterVisibilityStatus,
    this.kycStatus,
  });

  /// Paid, in-date premium placement. Takes precedence over the plain
  /// verified badge (API doc: recommended wins when both are true).
  bool get showRecommendedBadge =>
      isFeaturedTransporter && transporterVisibilityStatus == 'active';

  /// Approved transporter without an active subscription.
  bool get showTransporterBadge =>
      isTransporter && transporterVerificationStatus == 'approved';

  bool get transporterPending => transporterVerificationStatus == 'pending';

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
        isTransporter: json['isTransporter'] ?? false,
        transporterVerificationStatus: json['transporterVerificationStatus'],
        isFeaturedTransporter: json['isFeaturedTransporter'] ?? false,
        featuredTransporterUntil: json['featuredTransporterUntil'],
        transporterVisibilityStatus: json['transporterVisibilityStatus'],
        kycStatus: json['kycStatus'],
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
        'isTransporter': isTransporter,
        'transporterVerificationStatus': transporterVerificationStatus,
        'isFeaturedTransporter': isFeaturedTransporter,
        'featuredTransporterUntil': featuredTransporterUntil,
        'transporterVisibilityStatus': transporterVisibilityStatus,
        'kycStatus': kycStatus,
      };
}
