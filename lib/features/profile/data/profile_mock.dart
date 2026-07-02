class Profile {
  final String name;
  final String email;
  final String phone;
  final bool idVerified;
  final bool phoneVerified;
  final double rating;
  final int completedDeliveries;
  final int openDisputes;
  final bool recommended;

  const Profile({
    required this.name,
    required this.email,
    required this.phone,
    required this.idVerified,
    required this.phoneVerified,
    required this.rating,
    required this.completedDeliveries,
    required this.openDisputes,
    required this.recommended,
  });

  // free recommended-traveler eligibility (3+ deliveries, no disputes, verified)
  bool get eligibleForRecommended =>
      completedDeliveries >= 3 && openDisputes == 0 && idVerified && phoneVerified;
}

const currentProfile = Profile(
  name: 'Sami Trabelsi',
  email: 'sami.trabelsi@email.com',
  phone: '+216 22 345 678',
  idVerified: true,
  phoneVerified: true,
  rating: 4.8,
  completedDeliveries: 7,
  openDisputes: 0,
  recommended: false,
);
