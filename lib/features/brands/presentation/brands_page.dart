import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/utils/notify.dart';
import '../data/brand_model.dart';
import 'package:url_launcher/url_launcher.dart';

class BrandsPage extends StatefulWidget {
  const BrandsPage({super.key});

  @override
  State<BrandsPage> createState() => _BrandsPageState();
}

class _BrandsPageState extends State<BrandsPage> {
  final _repo = BrandsRepository();
  List<Brand> _brands = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.list();
      if (mounted) setState(() { _brands = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

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
                  'post_your_delivery_request'.tr,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 4.h),
                Text(
                  'take_a_look_at_the_brands_that_have_to_offer'.tr,
                  style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                ),
                SizedBox(height: 20.h),
                if (_loading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h),
                    child: const Center(child: CircularProgressIndicator()),
                  )
                else if (_brands.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h),
                    child: Center(
                      child: Text('no_brands_yet'.tr,
                          style: TextStyle(
                              fontSize: 13.sp, color: cs.onSurfaceVariant)),
                    ),
                  )
                else
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14.h,
                    crossAxisSpacing: 14.w,
                    childAspectRatio: 1.15,
                    children: [
                      for (final b in _brands) _BrandCard(brand: b),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
            child: ElevatedButton(
              onPressed: () => Get.back(),
              child: Text('next'.tr),
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
            // the admin can upload a logo; fall back to an initial chip
            ClipOval(
              child: Container(
                width: 54.r,
                height: 54.r,
                alignment: Alignment.center,
                color: brand.color,
                child: (brand.logoUrl ?? '').isEmpty
                    ? Text(
                        brand.name[0],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : Image.network(
                        brand.logoUrl!,
                        width: 54.r,
                        height: 54.r,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          brand.name[0],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
