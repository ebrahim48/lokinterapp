import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/utils/notify.dart';
import '../data/mock_brands.dart';
import 'package:url_launcher/url_launcher.dart';

class BrandsPage extends StatelessWidget {
  const BrandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
              children: [
                Text(
                  'Post your delivery request',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 4.h),
                Text(
                  'Take a look at the brands that have to offer',
                  style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                ),
                SizedBox(height: 20.h),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14.h,
                  crossAxisSpacing: 14.w,
                  childAspectRatio: 1.15,
                  children: [
                    for (final b in mockBrands) _BrandCard(brand: b),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
            child: ElevatedButton(
              onPressed: () => Get.back(),
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  final Brand brand;
  const _BrandCard({required this.brand});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      // open the brand's own site in the browser
      onTap: () async {
        final uri = Uri.parse(
            brand.url.startsWith('http') ? brand.url : 'https://${brand.url}');
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          toast('Could not open ${brand.url}');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54.r,
              height: 54.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: brand.color, shape: BoxShape.circle),
              child: Text(
                brand.name[0],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              brand.name,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
