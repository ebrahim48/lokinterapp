import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import '../../posts/presentation/widgets/transporter_chip.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../profile/data/profile_repository.dart';
import '../data/review_model.dart';
import 'package:get/get.dart';

/// Own reviews (no args) or another user's public profile
/// ([userId] set) — the website's `user-reviews/:id` page.
class UserReviewsPage extends StatefulWidget {
  final int? userId;
  final String? userName;
  const UserReviewsPage({super.key, this.userId, this.userName});

  @override
  State<UserReviewsPage> createState() => _UserReviewsPageState();
}

class _UserReviewsPageState extends State<UserReviewsPage> {
  final _repo = ProfileRepository();
  List<Review> _reviews = [];
  RatingSummary? _summaryInfo;
  bool _loading = true;
  String? _error;

  double get _average => _reviews.isEmpty
      ? 0
      : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.reviews(widget.userId),
        _repo.userInfo(widget.userId).then<RatingSummary?>((s) => s).catchError((_) => null),
      ]);
      if (!mounted) return;
      setState(() {
        _reviews = results[0] as List<Review>;
        _summaryInfo = results[1] as RatingSummary?;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.userId == null
        ? 'reviews'.tr
        : (widget.userName?.isNotEmpty ?? false)
            ? widget.userName!
            : (_summaryInfo?.userName.isNotEmpty ?? false)
                ? _summaryInfo!.userName
                : 'profile'.tr;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                      TextButton(onPressed: _load, child: Text('retry'.tr)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                    children: [
                      if (_summaryInfo != null) ...[
                        _profileHeader(context, _summaryInfo!),
                        SizedBox(height: 14.h),
                      ],
                      if (_reviews.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.h),
                          child: Center(
                            child: Text('no_reviews_yet'.tr,
                                style:
                                    TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                          ),
                        )
                      else ...[
                        _summary(context),
                        SizedBox(height: 20.h),
                        for (final r in _reviews) ...[
                          _reviewCard(context, r),
                          SizedBox(height: 12.h),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }

  // website public profile: avatar + authoritative overall rating, then
  // role-split averages, activity counts, and verification badges
  Widget _profileHeader(BuildContext context, RatingSummary s) {
    final cs = Theme.of(context).colorScheme;
    final name = s.userName.isNotEmpty
        ? s.userName
        : (widget.userName ?? '').isNotEmpty
            ? widget.userName!
            : 'user'.tr;

    Widget chip(String label, bool ok) => Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: ok
                ? AppPalette.verified.withValues(alpha: 0.12)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ok ? Icons.verified : Icons.remove_circle_outline,
                  size: 13.sp, color: ok ? AppPalette.verified : cs.onSurfaceVariant),
              SizedBox(width: 4.w),
              Text(label,
                  style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                      color: ok ? AppPalette.verified : cs.onSurfaceVariant)),
            ],
          ),
        );

    Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 16.sp, fontWeight: FontWeight.w800, color: cs.onSurface)),
              SizedBox(height: 2.h),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
            ],
          ),
        );

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28.r,
                backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
                backgroundImage: s.avatarUrl != null
                    ? CachedNetworkImageProvider(s.avatarUrl!)
                    : null,
                child: s.avatarUrl != null
                    ? null
                    : Text(name[0].toUpperCase(),
                        style: TextStyle(
                            color: AppPalette.primary,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800)),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // same chip the post cards and own profile show
                    if (s.isApprovedTransporter) ...[
                      TransporterChip(recommended: s.isFeaturedTransporter),
                      SizedBox(height: 6.h),
                    ],
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface)),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        _stars(s.averageStars.round()),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            s.averageStars == 0
                                ? 'no_ratings_yet'.tr
                                : '${s.averageStars.toStringAsFixed(1)} · ${'reviews_count'.trParams({'count': '${s.totalRates}'})}',
                            style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    if (s.operatingCountries.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 4.w,
                        runSpacing: 4.h,
                        children: [
                          for (final c in s.operatingCountries)
                            CountryFlag.fromCountryCode(c, height: 12.h, width: 18.w),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 22.h, color: cs.outline),
          Row(
            children: [
              stat('as_traveler'.tr,
                  s.averageStarsAsTraveler == 0 ? '—' : s.averageStarsAsTraveler.toStringAsFixed(1)),
              stat('as_sender'.tr,
                  s.averageStarsAsSender == 0 ? '—' : s.averageStarsAsSender.toStringAsFixed(1)),
              stat('trips'.tr, '${s.totalTrips}'),
              stat('requests'.tr, '${s.totalRequests}'),
              stat('delivers'.tr, '${s.totalDelivers}'),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              chip(s.identityVerified ? 'id_verified'.tr : 'id_not_verified'.tr,
                  s.identityVerified),
              chip(s.phoneVerified ? 'phone_verified'.tr : 'phone_not_verified'.tr,
                  s.phoneVerified),
              chip(s.emailVerified ? 'email_verified'.tr : 'email_not_verified'.tr,
                  s.emailVerified),
            ],
          ),
        ],
      ),
    );
  }

  // big average on the left, star-count breakdown on the right
  Widget _summary(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final counts = <int, int>{for (var s = 1; s <= 5; s++) s: 0};
    for (final r in _reviews) {
      counts[r.rating.clamp(1, 5)] = (counts[r.rating.clamp(1, 5)] ?? 0) + 1;
    }

    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(_average.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 38.sp, fontWeight: FontWeight.w800, color: cs.onSurface)),
              _stars(_average.round()),
              SizedBox(height: 4.h),
              Text('${_reviews.length} review${_reviews.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
            ],
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              children: [
                for (var s = 5; s >= 1; s--) _bar(context, s, counts[s] ?? 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, int stars, int count) {
    final cs = Theme.of(context).colorScheme;
    final ratio = _reviews.isEmpty ? 0.0 : count / _reviews.length;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        children: [
          Text('$stars', style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
          SizedBox(width: 4.w),
          Icon(Icons.star, size: 11.sp, color: Colors.amber),
          SizedBox(width: 8.w),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6.h,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(Colors.amber),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 18.w,
            child: Text('$count',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _stars(int n) {
    return Row(
      children: List.generate(
        5,
        (i) => Icon(i < n ? Icons.star : Icons.star_border, size: 16.sp, color: Colors.amber),
      ),
    );
  }

  Widget _reviewCard(BuildContext context, Review r) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18.r,
                backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
                child: Text(r.reviewer.isEmpty ? '?' : r.reviewer[0],
                    style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w700)),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.reviewer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                    SizedBox(height: 3.h),
                    _stars(r.rating),
                  ],
                ),
              ),
              Text(chatTime(r.date),
                  style: TextStyle(fontSize: 10.5.sp, color: cs.onSurfaceVariant)),
            ],
          ),
          if (r.comment.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(r.comment,
                style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant, height: 1.45)),
          ],
        ],
      ),
    );
  }
}
