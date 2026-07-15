import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/notify.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../auth/data/auth_repository.dart';
import '../../lookups/data/lookup_models.dart';
import '../../lookups/data/lookups_repository.dart';
import '../data/profile_repository.dart';
import 'controllers/profile_controller.dart';

class BasicInfoPage extends StatefulWidget {
  const BasicInfoPage({super.key});

  @override
  State<BasicInfoPage> createState() => _BasicInfoPageState();
}

class _BasicInfoPageState extends State<BasicInfoPage> {
  final _repo = ProfileRepository();
  final _lookups = LookupsRepository();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  List<Country> _countries = [];
  String? _country; // country name shown in the dropdown
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = Get.find<SessionService>().user.value;
    final parts = (user?.fullName ?? '').split(' ');
    _firstName = TextEditingController(
        text: user?.firstName ?? (parts.isNotEmpty ? parts.first : ''));
    _lastName = TextEditingController(
        text: user?.lastName ?? (parts.length > 1 ? parts.sublist(1).join(' ') : ''));
    _email = TextEditingController(text: user?.email ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');

    _lookups.countries().then((list) {
      if (!mounted) return;
      setState(() {
        _countries = list;
        _country = list
            .firstWhereOrNull((c) => c.iso2 == user?.country)
            ?.name;
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstName.text.trim().isEmpty || _email.text.trim().isEmpty) {
      toast('Name and email are required');
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.updateProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        country: _countries.firstWhereOrNull((c) => c.name == _country)?.iso2,
      );
      await AuthRepository().me(); // pull the fresh profile into the session
      if (Get.isRegistered<ProfileController>()) Get.find<ProfileController>().load();
      toast('Profile updated');
      Get.back();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Get.find<SessionService>().user.value;
    final summary =
        Get.isRegistered<ProfileController>() ? Get.find<ProfileController>().summary.value : null;
    final initial = (user?.fullName.isNotEmpty ?? false) ? user!.fullName[0] : '?';

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
                  child: Text(initial,
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
            label: 'First name',
            hint: 'first name',
            icon: Icons.person_outline,
            controller: _firstName,
          ),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'Last name',
            hint: 'last name',
            icon: Icons.person_outline,
            controller: _lastName,
          ),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'Email',
            hint: 'you@email.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            controller: _email,
          ),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'Phone',
            hint: 'phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            controller: _phone,
          ),
          SizedBox(height: 16.h),
          LokDropdownField(
            label: 'Country',
            hint: 'select a country',
            icon: Icons.public,
            options: _countries.map((c) => c.name).toList(),
            value: _country,
            onChanged: (v) => setState(() => _country = v),
          ),
          SizedBox(height: 20.h),
          _verifyRow(context, 'Identity document', user?.identityVerified ?? false),
          SizedBox(height: 10.h),
          _verifyRow(context, 'Phone number', summary?.phoneVerified ?? false),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 20.r,
                    height: 20.r,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save changes'),
          ),
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
            TextButton(
              onPressed: () => toast('Verification runs from the web dashboard for now'),
              child: const Text('Verify'),
            ),
        ],
      ),
    );
  }
}
