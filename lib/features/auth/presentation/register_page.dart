import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/lok_busy_button.dart';
import '../../../core/widgets/lok_fields.dart';
import 'controllers/register_controller.dart';
import 'login_page.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(RegisterController());
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 24.h),
        children: [
          Text('create_account'.tr, style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: 6.h),
          Text(
            'join_lokinter_to_send_and_carry_parcels'.tr,
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
          ),
          SizedBox(height: 22.h),
          Text(
            'i_want_to_register_as'.tr,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          SizedBox(height: 10.h),
          _roleSelector(context, c),
          SizedBox(height: 20.h),
          LokTextField(
            label: 'first_name'.tr,
            hint: 'first_name_2'.tr,
            icon: Icons.person_outline,
            required: true,
            controller: c.firstName,
          ),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'last_name'.tr,
            hint: 'last_name_2'.tr,
            icon: Icons.person_outline,
            required: true,
            controller: c.lastName,
          ),
          SizedBox(height: 16.h),
          Obx(() => LokDropdownField(
                label: 'country_of_residence'.tr,
                hint: 'select_a_country'.tr,
                icon: Icons.public,
                required: true,
                options: c.countryNames,
                searchable: true,
                value: c.country.value,
                onChanged: (v) => c.country.value = v,
              )),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'phone_number'.tr,
            hint: 'phone_number_2'.tr,
            icon: Icons.phone_outlined,
            required: true,
            keyboardType: TextInputType.phone,
            controller: c.phone,
          ),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'email'.tr,
            hint: 'you_email_com'.tr,
            icon: Icons.mail_outline,
            required: true,
            keyboardType: TextInputType.emailAddress,
            controller: c.email,
          ),
          SizedBox(height: 16.h),
          LokPasswordField(controller: c.password),
          Obx(() => c.isTransporter ? _businessSection(context, c) : const SizedBox.shrink()),
          SizedBox(height: 22.h),
          LokBusyButton(busy: c.busy, label: 'register'.tr, onPressed: c.requestOtp),
          SizedBox(height: 18.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'already_have_an_account'.tr,
                style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
              ),
              GestureDetector(
                onTap: () => Get.off(() => const LoginPage()),
                child: Text(
                  'sign_in'.tr,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleSelector(BuildContext context, RegisterController c) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          _roleTile(
            context,
            c,
            RegisterRole.transporter,
            Icons.local_shipping_outlined,
            'Transporter',
            'Register as a transporter / logistics company',
          ),
          Divider(height: 1, color: cs.outline),
          _roleTile(
            context,
            c,
            RegisterRole.individual,
            Icons.person_outline,
            'Individual (Sender & Traveler)',
            'Register as an individual user (sender or traveler)',
          ),
        ],
      ),
    );
  }

  Widget _roleTile(BuildContext context, RegisterController c, RegisterRole role,
      IconData icon, String title, String subtitle) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final selected = c.role.value == role;
      return InkWell(
        onTap: () => c.role.value = role,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? AppPalette.primary : cs.outline,
                size: 22.sp,
              ),
              SizedBox(width: 12.w),
              Icon(icon, color: cs.onSurfaceVariant, size: 24.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _businessSection(BuildContext context, RegisterController c) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 24.h),
        Text(
          'business_details'.tr,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        SizedBox(height: 4.h),
        Text(
          'collected_once_so_you_get_a_transporter_badge_an'.tr,
          style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.4),
        ),
        SizedBox(height: 16.h),
        LokTextField(
          label: 'legal_name'.tr,
          hint: 'business_legal_name'.tr,
          icon: Icons.business_outlined,
          required: true,
          controller: c.businessName,
        ),
        SizedBox(height: 16.h),
        LokTextField(
          label: 'address'.tr,
          hint: 'business_address'.tr,
          icon: Icons.location_on_outlined,
          required: true,
          maxLines: 2,
          controller: c.address,
        ),
        SizedBox(height: 16.h),
        Obx(() => LokMultiSelectField(
              label: 'countries_of_operation'.tr,
              hint: 'select_countries'.tr,
              icon: Icons.public,
              required: true,
              options: c.countryNames,
              selected: c.operatingCountries.toList(),
              onChanged: (v) => c.operatingCountries.value = v,
            )),
        SizedBox(height: 16.h),
        _docLabel(context, 'Transport license'),
        SizedBox(height: 6.h),
        Obx(() => LokUploadField(
              label: 'upload_transport_license'.tr,
              fileName: c.licenseFile.value?.name,
              onTap: c.pickLicense,
            )),
        SizedBox(height: 16.h),
        _docLabel(context, 'Transporter legal documents'),
        SizedBox(height: 6.h),
        Obx(() => LokUploadField(
              label: 'upload_legal_documents'.tr,
              fileName: c.legalFile.value?.name,
              onTap: c.pickLegal,
            )),
        SizedBox(height: 10.h),
        Text(
          'documents_are_reviewed_by_our_team_before_your_t'.tr,
          style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.4),
        ),
      ],
    );
  }

  Widget _docLabel(BuildContext context, String text) {
    return Text.rich(
      TextSpan(
        text: text,
        children: const [TextSpan(text: ' *', style: TextStyle(color: AppPalette.primary))],
      ),
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
