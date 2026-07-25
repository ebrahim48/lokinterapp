import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/utils/notify.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/lok_busy_button.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../auth/data/auth_repository.dart';
import '../../lookups/data/lookup_models.dart';
import '../../lookups/data/lookups_repository.dart';
import '../data/kyc_repository.dart';
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

  // avatar picked locally, uploaded on Save
  File? _pickedAvatar;

  // the stored avatar can 404 into an HTML page — fall back to the initial
  bool _avatarBroken = false;

  // KYC synced on open, same as the website's basic-info form
  KycStatus? _kyc;

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
        _country = list.firstWhereOrNull((c) => c.iso2 == user?.country)?.name;
      });
    }).catchError((_) {});

    KycRepository().status().then((s) {
      if (mounted) setState(() => _kyc = s);
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

  Future<void> _pickAvatar() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (img != null && mounted) setState(() => _pickedAvatar = File(img.path));
  }

  Future<void> _save() async {
    if (_firstName.text.trim().isEmpty || _email.text.trim().isEmpty) {
      toast('Name and email are required');
      return;
    }
    if (!isValidEmail(_email.text)) {
      toast('That email address does not look right');
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
        avatarPath: _pickedAvatar?.path,
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

  // ---- KYC (hosted flow, opened in the system browser) ----

  String get _kycActionLabel => switch (_kyc?.status ?? 'not_started') {
        'pending' => 'Resume',
        'declined' => 'Contact support',
        _ => 'Verify',
      };

  Future<void> _startKyc() async {
    if (_kyc?.status == 'declined') {
      // website shows "Verification Refused - Contact Support"
      toast('Your verification was refused — please contact support.');
      return;
    }
    try {
      final url = await KycRepository().startVerification();
      if (url == null) {
        // verify may short-circuit when already approved/pending — resync
        final s = await KycRepository().status();
        if (mounted) setState(() => _kyc = s);
        toast(s.verified
            ? 'Your identity is already verified.'
            : 'Verification is not available right now');
        return;
      }
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) toast('Could not open the verification page');
    } on AppException catch (e) {
      toastError(e);
    }
  }

  // ---- WhatsApp phone verification (2-step modal, website parity) ----

  Future<void> _verifyPhone() async {
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      toast('Add your phone number first');
      return;
    }
    final dial = TextEditingController(text: '+');
    final otp = TextEditingController();
    final step = 0.obs;
    final busy = false.obs;

    await Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 18.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
        ),
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verify phone number',
                  style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: 6.h),
              Text(
                step.value == 0
                    ? 'We will send a verification code to your WhatsApp.'
                    : 'Enter the 4-digit code we sent to your WhatsApp.',
                style: TextStyle(
                    fontSize: 13.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: 16.h),
              if (step.value == 0) ...[
                LokTextField(
                  label: 'Country code',
                  hint: '+216',
                  icon: Icons.flag_outlined,
                  keyboardType: TextInputType.phone,
                  controller: dial,
                ),
                SizedBox(height: 12.h),
                LokTextField(
                  label: 'Phone number',
                  hint: 'phone number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  controller: _phone,
                ),
                SizedBox(height: 18.h),
                LokBusyButton(
                  busy: busy,
                  label: 'Send code',
                  onPressed: () async {
                    final code = dial.text.trim();
                    if (code.length < 2) {
                      toast('Enter your country dial code');
                      return;
                    }
                    busy.value = true;
                    try {
                      await _repo.sendPhoneOtp(_phone.text.trim(), code);
                      step.value = 1;
                      toast('Code sent to your WhatsApp');
                    } on AppException catch (e) {
                      toastError(e);
                    } finally {
                      busy.value = false;
                    }
                  },
                ),
              ] else ...[
                LokTextField(
                  label: 'Verification code',
                  hint: '4-digit code',
                  icon: Icons.pin_outlined,
                  keyboardType: TextInputType.number,
                  controller: otp,
                ),
                SizedBox(height: 18.h),
                LokBusyButton(
                  busy: busy,
                  label: 'Verify',
                  onPressed: () async {
                    busy.value = true;
                    try {
                      await _repo.verifyPhoneOtp(
                          otp.text.trim(), _phone.text.trim(), dial.text.trim());
                      await AuthRepository().me();
                      if (Get.isRegistered<ProfileController>()) {
                        Get.find<ProfileController>().load();
                      }
                      Get.back();
                      toast('Phone number verified');
                      if (mounted) setState(() {});
                    } on AppException catch (e) {
                      toastError(e);
                    } finally {
                      busy.value = false;
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ---- change password (website keeps this on the basic-info page) ----

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final busy = false.obs;

    await Get.bottomSheet(
      Container(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 18.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change password', style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 16.h),
            LokPasswordField(label: 'Current password', controller: current),
            SizedBox(height: 12.h),
            LokPasswordField(label: 'New password', controller: next),
            SizedBox(height: 12.h),
            LokPasswordField(label: 'Confirm new password', controller: confirm),
            SizedBox(height: 18.h),
            LokBusyButton(
              busy: busy,
              label: 'Update password',
              onPressed: () async {
                if (!isValidPassword(next.text)) {
                  toast('New password must be at least 8 characters');
                  return;
                }
                if (next.text != confirm.text) {
                  toast('Passwords do not match');
                  return;
                }
                busy.value = true;
                try {
                  await AuthRepository().changePassword(current.text, next.text);
                  Get.back();
                  toast('Password updated');
                } on AppException catch (e) {
                  toastError(e);
                } finally {
                  busy.value = false;
                }
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Get.find<SessionService>().user.value;
    final summary =
        Get.isRegistered<ProfileController>() ? Get.find<ProfileController>().summary.value : null;
    final initial = (user?.fullName.isNotEmpty ?? false) ? user!.fullName[0] : '?';
    final stored =
        (user?.imageUrl != null && user!.imageUrl!.isNotEmpty) ? fixMediaUrl(user.imageUrl!) : null;
    final avatarUrl = _avatarBroken ? null : stored;

    final identityVerified = _kyc?.verified ?? user?.identityVerified ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Basic info')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44.r,
                    backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
                    backgroundImage: _pickedAvatar != null
                        ? FileImage(_pickedAvatar!)
                        : (avatarUrl != null ? NetworkImage(avatarUrl) : null),
                    onBackgroundImageError: avatarUrl == null
                        ? null
                        : (_, __) {
                            // fires while painting, so defer the rebuild
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _avatarBroken = true);
                            });
                          },
                    child: (_pickedAvatar == null && avatarUrl == null)
                        ? Text(initial,
                            style: TextStyle(
                                color: AppPalette.primary,
                                fontSize: 32.sp,
                                fontWeight: FontWeight.w800))
                        : null,
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
          // email is the account identity — read-only, same as the website
          LokTextField(
            label: 'Email',
            hint: 'you@email.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            controller: _email,
            readOnly: true,
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
          _verifyRow(
            context,
            'Identity document',
            identityVerified,
            actionLabel: _kycActionLabel,
            onVerify: _startKyc,
          ),
          SizedBox(height: 10.h),
          _verifyRow(
            context,
            'Phone number',
            summary?.phoneVerified ?? false,
            actionLabel: 'Verify',
            onVerify: _verifyPhone,
          ),
          SizedBox(height: 10.h),
          // change-password entry, styled like the verification rows
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline,
                    size: 18.sp, color: Theme.of(context).colorScheme.onSurfaceVariant),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text('Password',
                      style: TextStyle(
                          fontSize: 13.sp, color: Theme.of(context).colorScheme.onSurface)),
                ),
                TextButton(onPressed: _changePassword, child: const Text('Change')),
              ],
            ),
          ),
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

  Widget _verifyRow(
    BuildContext context,
    String label,
    bool verified, {
    required String actionLabel,
    required Future<void> Function() onVerify,
  }) {
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
                style: TextStyle(
                    fontSize: 12.sp,
                    color: AppPalette.verified,
                    fontWeight: FontWeight.w600))
          else
            TextButton(onPressed: onVerify, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
