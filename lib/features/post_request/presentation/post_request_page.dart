import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../../core/widgets/option_card.dart';
import '../../brands/presentation/brands_page.dart';
import '../../posts/data/mock_data.dart';
import '../../posts/data/models/post_model.dart';
import 'controllers/post_request_controller.dart';

const _currencies = ['USD', 'EUR', 'TND', 'GBP'];

class PostRequestPage extends StatelessWidget {
  const PostRequestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PostRequestController());
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
        children: [
          Text(
            'Post your delivery request',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 4.h),
          Text(
            'Choose the option that best fits your needs',
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
          ),
          SizedBox(height: 20.h),
          Obx(
            () => Row(
              children: [
                Expanded(
                  child: OptionCard(
                    icon: Icons.shopping_bag_outlined,
                    iconColor: AppPalette.primary,
                    title: 'Buy for me and deliver',
                    subtitle: 'Ask a traveler to buy a product and bring it to you',
                    selected: c.wantTo.value == WantTo.buyAndDeliver,
                    onTap: () => c.wantTo.value = WantTo.buyAndDeliver,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: OptionCard(
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppPalette.intlAccent,
                    title: 'Deliver ready item',
                    subtitle: 'You already have the item ready to be delivered',
                    selected: c.wantTo.value == WantTo.send,
                    onTap: () => c.wantTo.value = WantTo.send,
                  ),
                ),
              ],
            ),
          ),
          Obx(() => c.wantTo.value == null
              ? const SizedBox.shrink()
              : _locationStep(context, c)),
        ],
      ),
    );
  }

  Widget _locationStep(BuildContext context, PostRequestController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 14.h),
        Obx(
          () => Row(
            children: [
              Expanded(
                child: OptionCard(
                  icon: Icons.location_on,
                  iconColor: AppPalette.localAccent,
                  title: 'Local',
                  subtitle: 'Inside your country',
                  selected: c.location.value == PostLocation.local,
                  onTap: () => c.location.value = PostLocation.local,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OptionCard(
                  icon: Icons.flight,
                  iconColor: AppPalette.intlAccent,
                  title: 'International',
                  subtitle: 'From one country to another',
                  selected: c.location.value == PostLocation.international,
                  onTap: () => c.location.value = PostLocation.international,
                ),
              ),
            ],
          ),
        ),
        Obx(() => c.location.value == null
            ? const SizedBox.shrink()
            : _form(context, c)),
      ],
    );
  }

  Widget _form(BuildContext context, PostRequestController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 22.h),
        if (c.isBuy) ...[
          LokTextField(
            label: 'Item Name',
            hint: 'Item Name',
            icon: Icons.label_outline,
            required: true,
            controller: c.itemName,
          ),
          SizedBox(height: 12.h),
          _BrowseBrandsCard(onTap: () => Get.to(() => const BrandsPage())),
          SizedBox(height: 16.h),
        ],
        if (c.isLocal) ...[
          Obx(() => LokDropdownField(
                label: 'Inside',
                hint: 'inside country',
                icon: Icons.public,
                required: true,
                options: MockData.countries,
                value: c.insideCountry.value,
                onChanged: (v) => c.insideCountry.value = v,
              )),
          SizedBox(height: 16.h),
          Obx(() => LokDropdownField(
                label: 'From',
                hint: 'from city',
                icon: Icons.directions_car_filled_outlined,
                required: true,
                options: MockData.cities,
                value: c.fromCity.value,
                onChanged: (v) => c.fromCity.value = v,
              )),
          SizedBox(height: 16.h),
          Obx(() => LokDropdownField(
                label: 'To',
                hint: 'to city',
                icon: Icons.directions_car_filled_outlined,
                required: true,
                options: MockData.cities,
                value: c.toCity.value,
                onChanged: (v) => c.toCity.value = v,
              )),
        ] else ...[
          Obx(() => LokDropdownField(
                label: 'From',
                hint: 'from country',
                icon: Icons.public,
                required: true,
                options: MockData.countries,
                value: c.fromCountry.value,
                onChanged: (v) => c.fromCountry.value = v,
              )),
          SizedBox(height: 16.h),
          Obx(() => LokDropdownField(
                label: 'To',
                hint: 'to country',
                icon: Icons.public,
                required: true,
                options: MockData.countries,
                value: c.toCountry.value,
                onChanged: (v) => c.toCountry.value = v,
              )),
        ],
        SizedBox(height: 16.h),
        Obx(() => LokDateField(
              label: 'Before Date/time',
              hint: 'before (date and time)',
              required: true,
              value: c.beforeDate.value,
              onChanged: (d) => c.beforeDate.value = d,
            )),
        SizedBox(height: 16.h),
        LokTextField(
          label: 'KG',
          hint: 'kilograms',
          icon: Icons.scale_outlined,
          required: true,
          keyboardType: TextInputType.number,
          controller: c.weight,
        ),
        SizedBox(height: 16.h),
        Obx(() => LokDropdownField(
              label: 'Categories',
              hint: 'select categories',
              icon: Icons.category_outlined,
              required: true,
              options: MockData.categories,
              value: c.category.value,
              onChanged: (v) => c.category.value = v,
            )),
        SizedBox(height: 16.h),
        Obx(() => LokUploadField(
              fileName: c.pictureName.value,
              onTap: () => c.pictureName.value = 'product.jpg',
            )),
        SizedBox(height: 16.h),
        LokTextField(
          label: 'Item Description',
          hint: 'Describe the item (brand, link, color, size...)',
          maxLines: 4,
          controller: c.description,
        ),
        SizedBox(height: 16.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LokTextField(
                label: 'Traveler Profit',
                hint: 'offered profit',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                controller: c.profit,
              ),
            ),
            SizedBox(width: 12.w),
            SizedBox(
              width: 110.w,
              child: Obx(() => LokDropdownField(
                    label: 'Currency',
                    hint: 'USD',
                    icon: Icons.attach_money,
                    options: _currencies,
                    value: c.currency.value,
                    onChanged: (v) => c.currency.value = v,
                  )),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Obx(() => LokCheckbox(
              label: 'I accept terms and conditions',
              value: c.acceptedTerms.value,
              onChanged: (v) => c.acceptedTerms.value = v,
            )),
        SizedBox(height: 18.h),
        ElevatedButton(onPressed: () {}, child: const Text('Post')),
      ],
    );
  }
}

// "Browse Brands and shops" entry — local shops + international brands in one place.
class _BrowseBrandsCard extends StatelessWidget {
  final VoidCallback onTap;
  const _BrowseBrandsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppPalette.primary.withValues(alpha: 0.35)),
          gradient: LinearGradient(
            colors: [
              AppPalette.primary.withValues(alpha: 0.12),
              AppPalette.intlAccent.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46.r,
              height: 46.r,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46.r,
                    height: 46.r,
                    decoration: const BoxDecoration(color: AppPalette.primary, shape: BoxShape.circle),
                    child: Icon(Icons.storefront, color: Colors.white, size: 22.sp),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: EdgeInsets.all(3.r),
                      decoration: BoxDecoration(
                        color: AppPalette.intlAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 1.5),
                      ),
                      child: Icon(Icons.public, color: Colors.white, size: 12.sp),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse Brands and shops',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.primary,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'Discover local shops and international brands all in one place.',
                    style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.3),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppPalette.primary, size: 22.sp),
          ],
        ),
      ),
    );
  }
}
