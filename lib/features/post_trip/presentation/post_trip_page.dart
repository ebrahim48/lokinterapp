import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/lok_busy_button.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../../core/widgets/option_card.dart';
import '../../posts/data/models/post_model.dart';
import 'controllers/post_trip_controller.dart';

class PostTripPage extends StatelessWidget {
  final int? editId; // editing an existing trip instead of posting a new one
  const PostTripPage({super.key, this.editId});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(PostTripController(editId: editId), tag: '${editId ?? 'new'}');
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
        children: [
          Text(editId == null ? 'Post a Trip' : 'Edit Trip',
              style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: 4.h),
          Text(
            'where_are_you_traveling'.tr,
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
          ),
          SizedBox(height: 20.h),
          Obx(
            () => Row(
              children: [
                Expanded(
                  child: OptionCard(
                    icon: Icons.location_on,
                    iconColor: AppPalette.localAccent,
                    title: 'local'.tr,
                    subtitle: 'Travel within your city or region',
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
                    subtitle: 'Travel to any country around the world',
                    selected: c.location.value == PostLocation.international,
                    onTap: () => c.location.value = PostLocation.international,
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
          Obx(() => c.location.value == null
              ? const SizedBox.shrink()
              : _form(context, c)),
        ],
      ),
    );
  }

  Widget _form(BuildContext context, PostTripController c) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 22.h),
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
              label: 'trip_date_time'.tr,
              hint: 'trip_date_and_time'.tr,
              required: !c.noSpecificDate.value,
              withTime: c.isLocal,
              value: c.date.value,
              onChanged: (d) => c.date.value = d,
            )),
        // live mode has no airline field, and no pickup/dropoff on trips
        if (c.isLocal) ...[
          SizedBox(height: 12.h),
          Obx(() => LokCheckbox(
                label: 'no_specific_date_time'.tr,
                value: c.noSpecificDate.value,
                onChanged: (v) => c.noSpecificDate.value = v,
              )),
        ],
        SizedBox(height: 16.h),
        LokTextField(
          label: 'kg'.tr,
          hint: 'kilograms_available'.tr,
          icon: Icons.luggage_outlined,
          required: true,
          keyboardType: TextInputType.number,
          controller: c.weight,
        ),
        SizedBox(height: 16.h),
        Obx(() => LokMultiSelectField(
              label: 'rejected_categories_optional'.tr,
              hint: 'select_rejected_categories'.tr,
              icon: Icons.category_outlined,
              options: c.categoryNames,
              selected: c.rejectedCategories.toList(),
              onChanged: c.rejectedCategories.assignAll,
            )),
        SizedBox(height: 16.h),
        LokTextField(
          label: 'notes_optional'.tr,
          hint: 'stops_links_special_instructions'.tr,
          icon: Icons.notes_outlined,
          maxLines: 3,
          controller: c.notes,
        ),
        SizedBox(height: 18.h),
        Text(
          'By clicking post, I confirm that the details of this trip are '
          'accurate and I agree to post it.',
          style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.4),
        ),
        SizedBox(height: 16.h),
        LokBusyButton(
            busy: c.busy, label: editId == null ? 'Post' : 'Save changes', onPressed: c.submit),
      ],
    );
  }
}
