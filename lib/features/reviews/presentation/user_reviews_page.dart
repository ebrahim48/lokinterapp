import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/theme/app_palette.dart';
import '../../profile/data/profile_repository.dart';
import '../data/review_model.dart';

class UserReviewsPage extends StatefulWidget {
  const UserReviewsPage({super.key});

  @override
  State<UserReviewsPage> createState() => _UserReviewsPageState();
}

class _UserReviewsPageState extends State<UserReviewsPage> {
  final _repo = ProfileRepository();
  List<Review> _reviews = [];
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
      final reviews = await _repo.myReviews();
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _reviews.isEmpty
                  ? Center(
                      child: Text('No reviews yet',
                          style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                      children: [
                        Row(
                          children: [
                            Text(_average.toStringAsFixed(1),
                                style: TextStyle(
                                    fontSize: 40.sp, fontWeight: FontWeight.w800, color: cs.onSurface)),
                            SizedBox(width: 14.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _stars(_average.round()),
                                SizedBox(height: 4.h),
                                Text('${_reviews.length} reviews',
                                    style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
                        for (final r in _reviews) ...[
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
                child: Text(r.reviewer.isEmpty ? '?' : r.reviewer[0],
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
