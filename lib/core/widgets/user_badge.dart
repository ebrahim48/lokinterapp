import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../theme/app_palette.dart';

/// Small badge that sits beside a user's name so their standing is obvious
/// anywhere the name appears.
///
/// Precedence matches the API doc: a paid, in-date subscription shows the gold
/// "recommended" badge; an approved transporter without one shows the plain
/// transporter badge; otherwise a verified account gets the check.
enum UserBadgeKind { none, verified, transporter, recommended }

class UserBadge extends StatelessWidget {
  final UserBadgeKind kind;
  final bool compact; // icon only — for tight rows like cards

  const UserBadge(this.kind, {super.key, this.compact = false});

  static const _gold = Color(0xFFB8860B);

  /// Resolves the badge from the flags the API returns.
  factory UserBadge.from({
    Key? key,
    bool isTransporter = false,
    String? transporterVerificationStatus,
    bool isFeaturedTransporter = false,
    String? transporterVisibilityStatus,
    bool identityVerified = false,
    bool compact = false,
  }) {
    final approved =
        isTransporter && (transporterVerificationStatus ?? 'approved') == 'approved';
    if (approved && isFeaturedTransporter && transporterVisibilityStatus == 'active') {
      return UserBadge(UserBadgeKind.recommended, key: key, compact: compact);
    }
    if (approved) return UserBadge(UserBadgeKind.transporter, key: key, compact: compact);
    if (identityVerified) {
      return UserBadge(UserBadgeKind.verified, key: key, compact: compact);
    }
    return UserBadge(UserBadgeKind.none, key: key, compact: compact);
  }

  (IconData, Color, String) get _style => switch (kind) {
        UserBadgeKind.recommended =>
          (Icons.workspace_premium, _gold, 'recommended_transporter_2'),
        UserBadgeKind.transporter =>
          (Icons.local_shipping, AppPalette.primary, 'transporter'),
        UserBadgeKind.verified =>
          (Icons.verified, AppPalette.verified, 'verified_traveler'),
        UserBadgeKind.none => (Icons.circle, Colors.transparent, ''),
      };

  @override
  Widget build(BuildContext context) {
    if (kind == UserBadgeKind.none) return const SizedBox.shrink();
    final (icon, colour, label) = _style;

    if (compact) return Icon(icon, size: 14.sp, color: colour);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: colour.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.sp, color: colour),
          SizedBox(width: 4.w),
          Text(
            label.tr,
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              color: colour,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
