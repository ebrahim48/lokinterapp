import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/chat_gate.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/widgets/user_badge.dart';
import '../../posts/data/models/post_model.dart';
import '../../reviews/presentation/user_reviews_page.dart';

/// Popup shown after a successful DELIVER post when the backend reports
/// transporters that serve the posted route. Gives the sender a shortcut to
/// open a chat directly.
///
/// Only shows transporters that are BOTH approved AND have an active
/// visibility subscription — client-side safety filter on top of the
/// backend filter. If after filtering the list is empty, the dialog is
/// not shown (callers should check [shouldShow] first or use [showIfEligible]).
///
/// The dialog stays open while the sender visits a transporter's profile —
/// it closes only on "Close" or when a chat is opened. A chat opened from
/// here is linked to [postId] so it carries the route header and the
/// "Confirm agreement" button like any request chat.
class RecommendedTransportersDialog extends StatelessWidget {
  final List<Map<String, dynamic>> transporters;
  /// The delivery request that was just posted.
  final int? postId;
  const RecommendedTransportersDialog(
      {super.key, required this.transporters, this.postId});

  static const _approvalKeys = [
    'isApprovedTransporter',
    'transporterBadge',
    'showTransporterBadge',
  ];
  static const _visibilityKeys = [
    'visibilityActive',
    'featuredTransporter',
    'isFeaturedTransporter',
    'isRecommendedTransporter',
    'hasActiveSubscription',
  ];

  /// Paid visibility running — any of the flags the API uses for it.
  static bool isVisible(Map<String, dynamic> t) =>
      _visibilityKeys.any((k) => t[k] == true) ||
      '${t['visibilityStatus'] ?? ''}'.toLowerCase() == 'active';

  /// Safety net on top of the backend's own route + subscription filter:
  /// drop a transporter only when the payload says outright that they are
  /// not approved or have no active visibility. A flag the payload doesn't
  /// carry is not a "no" — reading it that way hid paid transporters whose
  /// row only had `visibilityStatus: active`.
  static List<Map<String, dynamic>> filter(
      List<Map<String, dynamic>> raw) {
    // the API lists every transporter on the route, the poster included — a
    // transporter posting a request must not be recommended to themselves
    final myId = Get.isRegistered<SessionService>()
        ? Get.find<SessionService>().user.value?.id
        : null;
    return raw.where((t) {
      final id = int.tryParse('${t['id'] ?? t['userId'] ?? ''}');
      if (myId != null && id == myId) return false;
      final approvalFlags = _approvalKeys.where(t.containsKey);
      final approved = approvalFlags.isEmpty ||
          approvalFlags.any((k) => t[k] == true);
      final hasVisibilityFlag = _visibilityKeys.any(t.containsKey) ||
          t.containsKey('visibilityStatus');
      return approved && (!hasVisibilityFlag || isVisible(t));
    }).toList();
  }

  /// Show the dialog only when at least one eligible transporter exists.
  /// Returns false (and shows nothing) when the filtered list is empty.
  static bool showIfEligible(List<Map<String, dynamic>> raw, {int? postId}) {
    final eligible = filter(raw);
    if (eligible.isEmpty) return false;
    Get.dialog(
      RecommendedTransportersDialog(transporters: eligible, postId: postId),
      // only "Close" or opening a chat dismisses it
      barrierDismissible: false,
    );
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

    return PopScope(
      // system back would dismiss the dialog too — keep it to "Close"
      canPop: false,
      child: AlertDialog(
        title: Text('recommended_transporters'.tr),
        contentPadding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
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
              SizedBox(height: 8.h),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 380.h),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < eligible.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: cs.outlineVariant),
                        _TransporterRow(t: eligible[i], postId: postId),
                      ],
                    ],
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
      ),
    );
  }
}

class _TransporterRow extends StatelessWidget {
  final Map<String, dynamic> t;
  final int? postId;
  const _TransporterRow({required this.t, this.postId});

  static int _int(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
  static double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  /// The API sends the avatar as a string or as {url, isFallback}. The
  /// fallback is an SVG placeholder the image widget can't draw, so it is
  /// treated as "no avatar" and the initial is shown instead.
  String? get _avatar {
    final a = t['avatar'];
    if (a is Map && a['isFallback'] == true) return null;
    final raw = (a is Map ? (a['signedUrl'] ?? a['url']) : null) ??
        t['avatarUrl'] ??
        t['profileImage'] ??
        (a is String ? a : null);
    final url = fixMediaUrl(raw?.toString());
    if (url == null || url.isEmpty || url.toLowerCase().endsWith('.svg')) {
      return null;
    }
    return url;
  }

  List<String> get _countries {
    final raw = t['operatingCountries'];
    if (raw is! List) return const [];
    return raw
        .map((e) => (e is Map ? e['code'] : e)?.toString().toUpperCase() ?? '')
        .where((c) => c.length == 2)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = t['name']?.toString() ?? '';
    final id = _int(t['id']);
    final trips = _int(t['successfulTripsCount']);
    final rating = _num(t['averageRating'] ?? t['rating'] ?? t['rate']);
    final reviews = _int(t['reviewsCount'] ?? t['ratesCount'] ?? t['ratingCount']);
    // the API localises these (and pluralises "review"); local text is only
    // the fallback for older payloads
    final tripsLabel = '${t['successfulTripsLabel'] ?? ''}'.trim();
    final reviewsLabel = '${t['reviewsLabel'] ?? ''}'.trim();
    final avatar = _avatar;
    final countries = _countries;
    final featured = RecommendedTransportersDialog.isVisible(t);
    final meta = TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant);

    // the dialog stays underneath — back from the profile returns here
    void openProfile() =>
        Get.to(() => UserReviewsPage(userId: id, userName: name));

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: openProfile,
            child: CircleAvatar(
              radius: 24.r,
              backgroundColor: cs.surfaceContainerHighest,
              backgroundImage:
                  avatar == null ? null : CachedNetworkImageProvider(avatar),
              child: avatar == null
                  ? Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: cs.onSurface),
                    )
                  : null,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: InkWell(
              onTap: openProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.sp, fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      UserBadge.from(
                        isApprovedTransporter: true,
                        isFeaturedTransporter: featured,
                        transporterVisibilityStatus: featured ? 'active' : null,
                        compact: true,
                      ),
                    ],
                  ),
                  if (countries.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Wrap(
                      spacing: 4.w,
                      runSpacing: 4.h,
                      children: [
                        for (final c in countries)
                          CountryFlag.fromCountryCode(c,
                              height: 12.h, width: 18.w),
                      ],
                    ),
                  ],
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          size: 13.sp, color: cs.onSurfaceVariant),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                            tripsLabel.isNotEmpty
                                ? tripsLabel
                                : 'successful_trips_count'
                                    .trParams({'count': '$trips'}),
                            style: meta),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          size: 14.sp, color: const Color(0xFFE0A100)),
                      SizedBox(width: 3.w),
                      Flexible(
                        child: Text(
                          reviewsLabel.isNotEmpty
                              ? reviewsLabel
                              : reviews == 0
                                  ? 'no_reviews_yet'.tr
                                  : '${rating.toStringAsFixed(1)} • ${'reviews_count'.trParams({'count': '$reviews'})}',
                          style: meta,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.primary,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              Get.back();
              openChat(
                PostUser(
                  id: id,
                  name: name,
                  avatarUrl: avatar,
                  isTransporter: true,
                  isRecommendedTransporter: featured,
                ),
                postId: postId,
              );
            },
            icon: Icon(Icons.chat_bubble_outline, size: 15.sp),
            label: Text('chat'.tr, style: TextStyle(fontSize: 12.sp)),
          ),
        ],
      ),
    );
  }
}
