import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/widgets/user_badge.dart';
import '../../../core/utils/chat_gate.dart';

/// Popup shown after a successful DELIVER post when the backend reports
/// transporters that serve the posted route. Gives the sender a shortcut to
/// open a chat directly.
///
/// Only shows transporters that are BOTH approved AND have an active
/// visibility subscription — client-side safety filter on top of the
/// backend filter. If after filtering the list is empty, the dialog is
/// not shown (callers should check [shouldShow] first or use [showIfEligible]).
class RecommendedTransportersDialog extends StatelessWidget {
  final List<Map<String, dynamic>> transporters;
  const RecommendedTransportersDialog({super.key, required this.transporters});

  /// Returns only transporters that pass the eligibility check:
  /// - isApprovedTransporter == true  (approved/accepted by admin)
  /// - visibilityActive == true       (active Increase Visibility subscription)
  static List<Map<String, dynamic>> filter(
      List<Map<String, dynamic>> raw) {
    return raw.where((t) {
      final approved = t['isApprovedTransporter'] == true ||
          t['transporterBadge'] == true ||
          t['showTransporterBadge'] == true;
      final visible = t['visibilityActive'] == true ||
          t['featuredTransporter'] == true ||
          t['isFeaturedTransporter'] == true;
      return approved && visible;
    }).toList();
  }

  /// Show the dialog only when at least one eligible transporter exists.
  /// Returns false (and shows nothing) when the filtered list is empty.
  static bool showIfEligible(List<Map<String, dynamic>> raw) {
    final eligible = filter(raw);
    if (eligible.isEmpty) return false;
    Get.dialog(RecommendedTransportersDialog(transporters: eligible));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Apply filter defensively in case the widget is constructed directly.
    final eligible = filter(transporters);

    if (eligible.isEmpty) {
      // Should not happen if callers use showIfEligible, but guard anyway.
      return AlertDialog(
        title: Text('recommended_transporters'.tr),
        content: Text('no_recommended_transporters_right_now'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('close'.tr)),
        ],
      );
    }

    return AlertDialog(
      title: Text('recommended_transporters'.tr),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'these_transporters_serve_your_route'.tr,
              style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
            ),
            SizedBox(height: 12.h),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 320.h),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: eligible.map((t) {
                    final name = t['name']?.toString() ?? '';
                    final id = t['id'] is int
                        ? t['id'] as int
                        : int.tryParse('${t['id']}') ?? 0;
                    // Both flags are guaranteed true after filter(), but keep
                    // explicit reads so UserBadge renders correctly.
                    final approved = t['isApprovedTransporter'] == true ||
                        t['transporterBadge'] == true ||
                        t['showTransporterBadge'] == true;
                    final featured = t['visibilityActive'] == true ||
                        t['featuredTransporter'] == true ||
                        t['isFeaturedTransporter'] == true;
                    final country =
                        t['country']?.toString() ?? t['countryName']?.toString() ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: cs.surfaceContainerHighest,
                        child: Text(
                          name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface),
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                            fontSize: 13.sp, fontWeight: FontWeight.w600),
                      ),
                      subtitle: country.isNotEmpty
                          ? Text(country,
                              style: TextStyle(
                                  fontSize: 11.sp,
                                  color: cs.onSurfaceVariant))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          UserBadge.from(
                            isApprovedTransporter: approved,
                            isFeaturedTransporter: featured,
                            transporterVisibilityStatus:
                                featured ? 'active' : null,
                            compact: true,
                          ),
                          SizedBox(width: 6.w),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.w, vertical: 4.h),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Get.back();
                              openChatWithUser(id, name: name);
                            },
                            child: Text('chat'.tr),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text('close'.tr),
        ),
      ],
    );
  }
}
