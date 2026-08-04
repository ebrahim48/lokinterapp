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

  // transporter business details the account already submitted
  final String? legalName;
  final String? address;
  final List<String> operatingCountries;

  // eligibility inputs for the free "recommended traveler" application
  final int successfulDeliveriesCount;
  final bool hasNoDisputesOnCompletedDeliveries;
  final bool phoneVerified;

  /// Live subscription, or null. The API returns
  /// `{status, planTitle, startDate, endDate}` only while it is still in date.
  final Map<String, dynamic>? subscription;

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
    this.legalName,
    this.address,
    this.operatingCountries = const [],
    this.successfulDeliveriesCount = 0,
    this.hasNoDisputesOnCompletedDeliveries = false,
    this.phoneVerified = false,
    this.subscription,
  });

  /// True while a paid plan is running — the subscribe button stays disabled.
  bool get hasActiveSubscription => subscription?['status'] == true;

  /// "2026-08-31" for the label; null when there is no subscription.
  String? get subscriptionEndsOn {
    final raw = subscription?['endDate'];
    if (raw == null) return null;
    return '$raw'.split('T').first.split(' ').first;
  }

  // --- recommended-traveler conditions (all four must hold) ---
  bool get hasThreeDeliveries => successfulDeliveriesCount >= 3;

  /// Only meaningful once there are deliveries to dispute, so it stays
  /// unchecked until the delivery count qualifies.
  bool get hasNoDisputes =>
      hasThreeDeliveries && hasNoDisputesOnCompletedDeliveries;

  bool get canApplyRecommendedTraveler =>
      hasThreeDeliveries && hasNoDisputes && identityVerified && phoneVerified;

  /// Paid, in-date premium placement. Takes precedence over the plain
  /// verified badge (API doc: recommended wins when both are true).
  bool get showRecommendedBadge =>
      isFeaturedTransporter && transporterVisibilityStatus == 'active';

  /// Approved transporter without an active subscription.
  bool get showTransporterBadge =>
      isTransporter && transporterVerificationStatus == 'approved';

  bool get transporterPending => transporterVerificationStatus == 'pending';

  /// The account already carries a transporter application. `isTransporter`
  /// alone is enough — the payload often omits the status field, and asking
  /// someone to apply again when the server already has them on file is wrong.
  bool get transporterApplied => isTransporter;

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
        legalName: json['legalName'],
        address: json['address'],
        operatingCountries: (json['operatingCountries'] as List? ?? const [])
            .map((e) => '$e')
            .toList(),
        successfulDeliveriesCount: json['successfulDeliveriesCount'] ?? 0,
        hasNoDisputesOnCompletedDeliveries:
            json['hasNoDisputesOnCompletedDeliveries'] ?? false,
        // the API sends an explicit flag now; fall back to the timestamp
        phoneVerified:
            json['phoneVerified'] ?? (json['phoneVerifiedAt'] != null),
        subscription: json['subscription'] is Map
            ? Map<String, dynamic>.from(json['subscription'])
            : null,
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
        'legalName': legalName,
        'address': address,
        'operatingCountries': operatingCountries,
        'successfulDeliveriesCount': successfulDeliveriesCount,
        'hasNoDisputesOnCompletedDeliveries': hasNoDisputesOnCompletedDeliveries,
        'phoneVerified': phoneVerified,
        'subscription': subscription,
      };
}
