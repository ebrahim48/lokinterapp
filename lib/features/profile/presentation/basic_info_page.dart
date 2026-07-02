import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../posts/data/mock_data.dart';
import '../data/profile_mock.dart';

class BasicInfoPage extends StatelessWidget {
  const BasicInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    const p = currentProfile;
    return Scaffold(
      appBar: AppBar(title: const Text('Basic info')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44.r,
                  backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
                  child: Text(p.name[0],
                      style: TextStyle(
                          color: AppPalette.primary, fontSize: 32.sp, fontWeight: FontWeight.w800)),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 15.r,
                    backgroundColor: AppPalette.primary,
                    child: Icon(Icons.edit, size: 14.sp, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),
          LokTextField(
            label: 'Full name',
            hint: p.name,
            icon: Icons.person_outline,
            controller: TextEditingController(text: p.name),
          ),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'Email',
            hint: p.email,
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            controller: TextEditingController(text: p.email),
          ),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'Phone',
            hint: p.phone,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            controller: TextEditingController(text: p.phone),
          ),
          SizedBox(height: 16.h),
          LokDropdownField(
            label: 'Country',
            hint: 'Tunisia',
            icon: Icons.public,
            options: MockData.countries,
            value: 'Tunisia',
            onChanged: (_) {},
          ),
          SizedBox(height: 20.h),
          _verifyRow(context, 'Identity document', p.idVerified),
          SizedBox(height: 10.h),
          _verifyRow(context, 'Phone number', p.phoneVerified),
          SizedBox(height: 24.h),
          ElevatedButton(onPressed: () {}, child: const Text('Save changes')),
        ],
      ),
    );
  }

  Widget _verifyRow(BuildContext context, String label, bool verified) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Icon(verified ? Icons.verified : Icons.shield_outlined,
              size: 18.sp, color: verified ? AppPalette.verified : cs.onSurfaceVariant),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13.sp, color: cs.onSurface)),
          ),
          if (verified)
            Text('Verified',
                style: TextStyle(fontSize: 12.sp, color: AppPalette.verified, fontWeight: FontWeight.w600))
          else
            TextButton(onPressed: () {}, child: const Text('Verify')),
        ],
      ),
    );
  }
}
