import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/notify.dart';
import '../../../core/widgets/lok_busy_button.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../lookups/data/lookup_models.dart';
import '../../lookups/data/lookups_repository.dart';
import '../data/profile_repository.dart';

/// Verifies the account's phone number over WhatsApp.
///
/// Two steps against the real API: `POST /auth/sendPhoneOtp` delivers a 4-digit
/// code, `POST /auth/verifyPhoneOtp` checks it and returns the updated user,
/// which the repository writes straight into the session — so the caller can
/// carry on with whatever the gate interrupted.
///
/// Pops `true` once the number is verified.
class VerifyPhonePage extends StatefulWidget {
  const VerifyPhonePage({super.key});

  static Future<bool> open() async =>
      await Get.to<bool>(() => const VerifyPhonePage()) ?? false;

  @override
  State<VerifyPhonePage> createState() => _VerifyPhonePageState();
}

class _VerifyPhonePageState extends State<VerifyPhonePage> {
  final _repo = ProfileRepository();
  final _lookups = LookupsRepository();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _busy = false.obs;

  List<Country> _countries = [];
  String? _country; // display name
  bool _sent = false;
  int _resendIn = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    final user = Get.find<SessionService>().user.value;
    _phone.text = user?.phone ?? '';
    _lookups.countries().then((list) {
      if (!mounted) return;
      setState(() {
        _countries = list;
        // start on the account's own country when we know it
        _country = list.firstWhereOrNull((c) => c.iso2 == user?.country)?.name;
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Country? get _selected =>
      _countries.firstWhereOrNull((c) => c.name == _country);

  // the API wants the dial code separately from the number
  String get _dialCode => '+${_selected?.phoneCode ?? ''}';

  void _startResendTimer() {
    _ticker?.cancel();
    setState(() => _resendIn = 60);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    final phone = _phone.text.trim();
    if (_selected == null || (_selected!.phoneCode).isEmpty) {
      toast('enter_your_country_dial_code'.tr);
      return;
    }
    if (phone.isEmpty) {
      toast('add_your_phone_number_first'.tr);
      return;
    }
    _busy.value = true;
    try {
      await _repo.sendPhoneOtp(phone, _dialCode);
      if (!mounted) return;
      setState(() => _sent = true);
      _startResendTimer();
      toast('code_sent_to_your_whatsapp'.tr);
    } on AppException catch (e) {
      toastError(e);
    } finally {
      _busy.value = false;
    }
  }

  Future<void> _verify() async {
    final code = _otp.text.trim();
    if (code.length != 4) {
      toast('enter_the_4_digit_code'.tr);
      return;
    }
    _busy.value = true;
    try {
      // on success the repository stores the updated user, so phoneVerified
      // is already true by the time we pop
      await _repo.verifyPhoneOtp(code, _phone.text.trim(), _dialCode);
      if (!mounted) return;
      toast('phone_number_verified'.tr);
      Get.back(result: true);
    } on AppException catch (e) {
      toastError(e);
    } finally {
      _busy.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('verify_phone_number'.tr)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
        children: [
          Text(
            _sent
                ? 'enter_the_code_we_sent_to_whatsapp'.tr
                : 'we_send_a_code_to_your_whatsapp'.tr,
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.5),
          ),
          SizedBox(height: 20.h),
          LokDropdownField(
            label: 'country'.tr,
            hint: 'select_a_country'.tr,
            icon: Icons.public,
            required: true,
            options: _countries.map((e) => e.name).toList(),
            searchable: true,
            value: _country,
            onChanged: (v) => setState(() => _country = v),
          ),
          if (_selected != null && _selected!.phoneCode.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text('${'country_code'.tr}: $_dialCode',
                style: TextStyle(fontSize: 11.5.sp, color: cs.onSurfaceVariant)),
          ],
          SizedBox(height: 16.h),
          LokTextField(
            label: 'phone_number'.tr,
            hint: 'phone_number_2'.tr,
            icon: Icons.phone_outlined,
            required: true,
            keyboardType: TextInputType.phone,
            controller: _phone,
            readOnly: _sent,
          ),
          if (_sent) ...[
            SizedBox(height: 16.h),
            LokTextField(
              label: 'verification_code'.tr,
              hint: '4_digit_code'.tr,
              icon: Icons.password_outlined,
              required: true,
              keyboardType: TextInputType.number,
              controller: _otp,
            ),
            SizedBox(height: 10.h),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _resendIn > 0 ? null : _send,
                child: Text(
                  _resendIn > 0
                      ? 'resend_in_seconds'.trParams({'s': '$_resendIn'})
                      : 'resend_code'.tr,
                  style: TextStyle(fontSize: 12.sp, color: AppPalette.primary),
                ),
              ),
            ),
            // let them correct a wrong number without leaving the screen
            TextButton(
              onPressed: () => setState(() {
                _sent = false;
                _otp.clear();
              }),
              child: Text('change_number'.tr, style: TextStyle(fontSize: 12.sp)),
            ),
          ],
          SizedBox(height: 20.h),
          LokBusyButton(
            busy: _busy,
            label: _sent ? 'verify'.tr : 'send_code'.tr,
            onPressed: _sent ? _verify : _send,
          ),
        ],
      ),
    );
  }
}
