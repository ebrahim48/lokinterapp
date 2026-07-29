import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/flags.dart';
import '../../data/models/post_model.dart';

// International = blue plane. Local = circular country flag so you can see WHICH country.
class ModeBadge extends StatelessWidget {
  final PostLocation location;
  final String? place; // country/city for the local flag
  final String? iso; // preferred — comes straight from the API
  final bool showLabel;
  final Color? labelColor;

  const ModeBadge({
    super.key,
    required this.location,
    this.place,
    this.iso,
    this.showLabel = true,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final local = location == PostLocation.local;
    final dot = local ? _flagDot() : _planeDot();

    if (!showLabel) return dot;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        SizedBox(height: 4.h),
        Text(
          local ? 'LOCAL' : 'INTERNATIONAL',
          style: TextStyle(
            fontSize: 9.sp,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w600,
            color: labelColor ?? (local ? AppPalette.localAccent : AppPalette.intlAccent),
          ),
        ),
      ],
    );
  }

  Widget _flagDot() {
    final code = iso ?? countryCodeFor(place ?? '');
    // unknown country → a neutral pin instead of the wrong flag
    if (code == null) {
      return Container(
        width: 34.r,
        height: 34.r,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppPalette.localAccent,
        ),
        child: Icon(Icons.location_on, size: 18.sp, color: Colors.white),
      );
    }
    return Container(
      width: 34.r,
      height: 34.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
        ],
      ),
      child: CountryFlag.fromCountryCode(
        code,
        height: 34.r,
        width: 34.r,
        shape: const Circle(),
      ),
    );
  }

  Widget _planeDot() {
    return Container(
      width: 34.r,
      height: 34.r,
      decoration: BoxDecoration(
        color: AppPalette.intlAccent.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.flight, color: AppPalette.intlAccent, size: 18.sp),
    );
  }
}
