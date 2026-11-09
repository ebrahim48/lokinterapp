import 'package:get/get.dart';

import '../../features/lookups/data/lookup_models.dart';
import '../services/session_service.dart';

/// Posting rules of the Nov 2026 update (REQ §1). The API enforces the same
/// rules; the app only stops the user before they fill in a form for nothing.

/// The signed-in account is an admin-approved transporter.
bool get isVerifiedTransporter =>
    Get.find<SessionService>().user.value?.isVerifiedTransporter ?? false;

/// Tunisia, however the lookup names it (ISO2, the country id the API uses,
/// or the English/French name).
bool isTunisia(Country? c) {
  if (c == null) return false;
  final name = c.name.trim().toLowerCase();
  return c.iso2.toUpperCase() == 'TN' ||
      c.id == 83 ||
      name == 'tunisia' ||
      name == 'tunisie';
}

bool isTunisiaName(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  return v == 'tn' || v == 'tunisia' || v == 'tunisie' || v == '83';
}
