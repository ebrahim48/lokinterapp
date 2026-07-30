import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/lok_busy_button.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../../core/widgets/option_card.dart';
import '../../brands/presentation/brands_page.dart';
import '../../posts/data/models/post_model.dart';
import 'controllers/post_request_controller.dart';

const _currencies = ['USD', 'EUR', 'TND', 'GBP'];

class PostRequestPage extends StatelessWidget {
  final int? editId; // editing an existing request instead of posting a new one
  const PostRequestPage({super.key, this.editId});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PostRequestController(editId: editId), tag: '${editId ?? 'new'}');
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
        children: [
          Text(
            editId == null ? 'Post your delivery request' : 'Edit delivery request',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 4.h),
          Text(
            'choose_the_option_that_best_fits_your_needs'.tr,
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
                    title: 'buy_for_me_and_deliver'.tr,
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
                    title: 'deliver_ready_item'.tr,
                    subtitle: 'You already have the item ready to be delivered',
                    selected: c.wantTo.value == WantTo.send,
                    onTap: () => c.wantTo.value = WantTo.send,
                  ),
                ),
              ],
            ),
          ),
          Obx(() => c.lookupFailed.value
              ? Padding(
                  padding: EdgeInsets.only(top: 16.h),
                  child: Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: AppPalette.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: AppPalette.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, color: AppPalette.primary, size: 20.sp),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            "Couldn't load countries, so the form can't be filled in.",
                            style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
                          ),
                        ),
                        TextButton(
                          onPressed: c.loadLookups,
                          child: Text('retry'.tr,
                              style: TextStyle(color: AppPalette.primary)),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink()),
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
                  title: 'local'.tr,
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
                  title: 'international'.tr,
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
            label: 'item_name_2'.tr,
            hint: 'item_name_2'.tr,
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
                label: 'inside'.tr,
                hint: 'inside_country'.tr,
                icon: Icons.public,
                required: true,
                options: c.countryNames,
                value: c.insideCountry.value,
                onChanged: (v) => c.insideCountry.value = v,
              )),
          SizedBox(height: 16.h),
          Obx(() => LokDropdownField(
                label: 'from'.tr,
                hint: 'from_city'.tr,
                icon: Icons.directions_car_filled_outlined,
                required: true,
                options: c.cityNames,
                value: c.fromCity.value,
                onChanged: (v) => c.fromCity.value = v,
              )),
          SizedBox(height: 16.h),
          Obx(() => LokDropdownField(
                label: 'to'.tr,
                hint: 'to_city'.tr,
                icon: Icons.directions_car_filled_outlined,
                required: true,
                options: c.cityNames,
                value: c.toCity.value,
                onChanged: (v) => c.toCity.value = v,
              )),
        ] else ...[
          Obx(() => LokDropdownField(
                label: 'from'.tr,
                hint: 'from_country'.tr,
                icon: Icons.public,
                required: true,
                options: c.countryNames,
                value: c.fromCountry.value,
                onChanged: (v) => c.fromCountry.value = v,
              )),
          SizedBox(height: 16.h),
          Obx(() => LokDropdownField(
                label: 'to'.tr,
                hint: 'to_country'.tr,
                icon: Icons.public,
                required: true,
                options: c.countryNames,
                value: c.toCountry.value,
                onChanged: (v) => c.toCountry.value = v,
              )),
        ],
        SizedBox(height: 16.h),
        Obx(() => LokDateField(
              label: 'before_date_time'.tr,
              hint: 'before_date_and_time'.tr,
              required: true,
              withTime: c.isLocal,
              value: c.beforeDate.value,
              onChanged: (d) => c.beforeDate.value = d,
            )),
        SizedBox(height: 16.h),
        LokTextField(
          label: 'kg'.tr,
          hint: 'kilograms'.tr,
          icon: Icons.scale_outlined,
          required: true,
          keyboardType: TextInputType.number,
          controller: c.weight,
        ),
        // live mode only asks for these on a local request
        if (c.isLocal) ...[
          SizedBox(height: 16.h),
          LokTextField(
            label: 'pickup_location'.tr,
            hint: 'where_the_item_is_collected'.tr,
            icon: Icons.place_outlined,
            required: true,
            controller: c.pickupLocation,
          ),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'dropoff_location'.tr,
            hint: 'where_it_should_be_delivered'.tr,
            icon: Icons.flag_outlined,
            required: true,
            controller: c.dropoffLocation,
          ),
        ],
        SizedBox(height: 16.h),
        Obx(() => LokMultiSelectField(
              label: 'categories'.tr,
              hint: 'select_categories'.tr,
              icon: Icons.category_outlined,
              required: true,
              options: c.categoryNames,
              selected: c.categories_.toList(),
              onChanged: c.categories_.assignAll,
            )),
        SizedBox(height: 16.h),
        Obx(() => LokUploadField(
              fileName: c.pictureName.value,
              onTap: c.pickProductPicture,
            )),
        SizedBox(height: 16.h),
        LokTextField(
          label: 'item_description'.tr,
          hint: 'describe_the_item_brand_link_color_size'.tr,
          maxLines: 4,
          controller: c.description,
        ),
        SizedBox(height: 16.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LokTextField(
                label: 'traveler_profit_2'.tr,
                hint: 'offered_profit'.tr,
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                controller: c.profit,
              ),
            ),
            SizedBox(width: 12.w),
            SizedBox(
              width: 110.w,
              child: Obx(() => LokDropdownField(
                    label: 'currency'.tr,
                    hint: 'usd'.tr,
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
              label: 'i_accept_terms_and_conditions'.tr,
              value: c.acceptedTerms.value,
              onChanged: (v) => c.acceptedTerms.value = v,
            )),
        SizedBox(height: 18.h),
        LokBusyButton(
            busy: c.busy, label: editId == null ? 'Post' : 'Save changes', onPressed: c.submit),
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
              child: Lottie.asset(
                'assets/animations/shopping_cart.json',
                width: 46.r,
                height: 46.r,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(color: AppPalette.primary, shape: BoxShape.circle),
                  child: Icon(Icons.storefront, color: Colors.white, size: 22.sp),
                ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'browse_brands_and_shops'.tr,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.primary,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'discover_local_shops_and_international_brands_al'.tr,
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
