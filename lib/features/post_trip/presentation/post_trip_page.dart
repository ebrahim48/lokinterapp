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
            'Where are you traveling?',
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
                    title: 'Local',
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
                    title: 'International',
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
                          child: const Text('Retry',
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
                label: 'Inside',
                hint: 'inside country',
                icon: Icons.public,
                required: true,
                options: c.countryNames,
                value: c.insideCountry.value,
                onChanged: (v) => c.insideCountry.value = v,
              )),
          SizedBox(height: 16.h),
          Obx(() => LokDropdownField(
                label: 'From',
                hint: 'from city',
                icon: Icons.directions_car_filled_outlined,
                required: true,
                options: c.cityNames,
                value: c.fromCity.value,
                onChanged: (v) => c.fromCity.value = v,
              )),
          SizedBox(height: 16.h),
          Obx(() => LokDropdownField(
                label: 'To',
                hint: 'to city',
                icon: Icons.directions_car_filled_outlined,
                required: true,
                options: c.cityNames,
                value: c.toCity.value,
                onChanged: (v) => c.toCity.value = v,
              )),
        ] else ...[
          Obx(() => LokDropdownField(
                label: 'From',
                hint: 'from country',
                icon: Icons.public,
                required: true,
                options: c.countryNames,
                value: c.fromCountry.value,
                onChanged: (v) => c.fromCountry.value = v,
              )),
          SizedBox(height: 16.h),
          Obx(() => LokDropdownField(
                label: 'To',
                hint: 'to country',
                icon: Icons.public,
                required: true,
                options: c.countryNames,
                value: c.toCountry.value,
                onChanged: (v) => c.toCountry.value = v,
              )),
        ],
        SizedBox(height: 16.h),
        Obx(() => LokDateField(
              label: 'Trip Date/time',
              hint: 'trip date and time',
              required: !c.noSpecificDate.value,
              withTime: c.isLocal,
              value: c.date.value,
              onChanged: (d) => c.date.value = d,
            )),
        if (c.isLocal) ...[
          SizedBox(height: 12.h),
          Obx(() => LokCheckbox(
                label: 'No specific date/time',
                value: c.noSpecificDate.value,
                onChanged: (v) => c.noSpecificDate.value = v,
              )),
        ] else ...[
          SizedBox(height: 16.h),
          LokTextField(
            label: 'Airline',
            hint: 'e.g. Air France',
            icon: Icons.flight_takeoff,
            required: true,
            controller: c.airline,
          ),
        ],
        SizedBox(height: 16.h),
        LokTextField(
          label: 'KG',
          hint: 'kilograms available',
          icon: Icons.luggage_outlined,
          required: true,
          keyboardType: TextInputType.number,
          controller: c.weight,
        ),
        SizedBox(height: 16.h),
        LokTextField(
          label: 'Pickup location',
          hint: 'where you collect items',
          icon: Icons.place_outlined,
          required: true,
          controller: c.pickupLocation,
        ),
        SizedBox(height: 16.h),
        LokTextField(
          label: 'Dropoff location',
          hint: 'where you hand them over',
          icon: Icons.flag_outlined,
          required: true,
          controller: c.dropoffLocation,
        ),
        SizedBox(height: 16.h),
        Obx(() => LokDropdownField(
              label: 'Rejected Categories (optional)',
              hint: 'select rejected categories',
              icon: Icons.category_outlined,
              options: c.categoryNames,
              value: c.rejectedCategory.value,
              onChanged: (v) => c.rejectedCategory.value = v,
            )),
        SizedBox(height: 16.h),
        LokTextField(
          label: 'Notes (optional)',
          hint: 'stops, links, special instructions...',
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
