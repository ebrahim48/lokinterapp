import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_palette.dart';
import '../data/review_mock.dart';

class UserReviewsPage extends StatelessWidget {
  const UserReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        children: [
          Row(
            children: [
              Text(averageRating.toStringAsFixed(1),
                  style: TextStyle(fontSize: 40.sp, fontWeight: FontWeight.w800, color: cs.onSurface)),
              SizedBox(width: 14.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stars(averageRating.round()),
                  SizedBox(height: 4.h),
                  Text('${mockReviews.length} reviews',
                      style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          for (final r in mockReviews) ...[
            _reviewCard(context, r),
            SizedBox(height: 12.h),
          ],
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
                radius: 16.r,
                backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
                child: Text(r.reviewer[0],
                    style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w700)),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(r.reviewer,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
              ),
              Text(r.date, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
            ],
          ),
          SizedBox(height: 8.h),
          _stars(r.rating),
          SizedBox(height: 8.h),
          Text(r.comment,
              style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, height: 1.4)),
        ],
      ),
    );
  }
}
