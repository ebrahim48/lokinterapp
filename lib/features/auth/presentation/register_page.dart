import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../posts/data/mock_data.dart';
import '../../shell/presentation/main_shell.dart';
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
          Text('Create account', style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: 6.h),
          Text(
            'Join Lokinter to send and carry parcels.',
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
          ),
          SizedBox(height: 22.h),
          Text(
            'I want to register as',
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
            label: 'First name',
            hint: 'first name',
            icon: Icons.person_outline,
            required: true,
            controller: c.firstName,
          ),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'Last name',
            hint: 'last name',
            icon: Icons.person_outline,
            required: true,
            controller: c.lastName,
          ),
          SizedBox(height: 16.h),
          Obx(() => LokDropdownField(
                label: 'Country',
                hint: 'select a country',
                icon: Icons.public,
                required: true,
                options: MockData.countries,
                value: c.country.value,
                onChanged: (v) => c.country.value = v,
              )),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'Phone number',
            hint: 'phone number',
            icon: Icons.phone_outlined,
            required: true,
            keyboardType: TextInputType.phone,
            controller: c.phone,
          ),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'Email',
            hint: 'you@email.com',
            icon: Icons.mail_outline,
            required: true,
            keyboardType: TextInputType.emailAddress,
            controller: c.email,
          ),
          SizedBox(height: 16.h),
          const LokPasswordField(),
          Obx(() => c.isTransporter ? _businessSection(context, c) : const SizedBox.shrink()),
          SizedBox(height: 22.h),
          ElevatedButton(
            onPressed: () => Get.offAll(() => const MainShell()),
            child: const Text('Register'),
          ),
          SizedBox(height: 18.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
              ),
              GestureDetector(
                onTap: () => Get.off(() => const LoginPage()),
                child: Text(
                  'Sign in',
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
          'Business details',
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        SizedBox(height: 4.h),
        Text(
          'Collected once so you get a Transporter badge and skip it later.',
          style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.4),
        ),
        SizedBox(height: 16.h),
        LokTextField(
          label: 'Legal name',
          hint: 'business / legal name',
          icon: Icons.business_outlined,
          required: true,
          controller: c.businessName,
        ),
        SizedBox(height: 16.h),
        LokTextField(
          label: 'Address',
          hint: 'business address',
          icon: Icons.location_on_outlined,
          required: true,
          maxLines: 2,
          controller: c.address,
        ),
        SizedBox(height: 16.h),
        Obx(() => LokDropdownField(
              label: 'Countries of operation',
              hint: 'select country',
              icon: Icons.public,
              required: true,
              options: MockData.countries,
              value: c.operatingCountry.value,
              onChanged: (v) => c.operatingCountry.value = v,
            )),
        SizedBox(height: 16.h),
        Obx(() => LokUploadField(
              label: 'Upload business documents',
              fileName: c.documentName.value,
              onTap: () => c.documentName.value = 'business-docs.pdf',
            )),
        SizedBox(height: 16.h),
        Obx(() => LokUploadField(
              label: 'Upload transportation license',
              fileName: c.licenseName.value,
              onTap: () => c.licenseName.value = 'license.pdf',
            )),
      ],
    );
  }
}
