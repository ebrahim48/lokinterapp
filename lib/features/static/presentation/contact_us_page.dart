import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/notify.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../lookups/data/lookups_repository.dart';

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({super.key});

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  final _lookups = LookupsRepository();

  late final TextEditingController _name;
  late final TextEditingController _email;
  final _phone = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final user = Get.find<SessionService>().user.value;
    _name = TextEditingController(text: user?.fullName ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _phone.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _message.text.trim().isEmpty) {
      toast('name_email_and_message_are_required'.tr);
      return;
    }
    if (!isValidEmail(_email.text)) {
      toast('that_email_address_does_not_look_right'.tr);
      return;
    }
    setState(() => _sending = true);
    try {
      await _lookups.sendContactMessage(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        subject: _subject.text.trim(),
        message: _message.text.trim(),
      );
      if (!mounted) return;
      toast('message_sent_the_team_will_get_back_to_you'.tr);
      Get.back();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('contact_us'.tr)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        children: [
          Text('wed_love_to_hear_from_you'.tr,
              style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 6.h),
          Text('send_us_a_message_and_the_team_will_get_back_to'.tr,
              style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
          SizedBox(height: 22.h),
          LokTextField(
              label: 'name'.tr, hint: 'your_name'.tr, icon: Icons.person_outline, controller: _name),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'email'.tr,
            hint: 'you_email_com'.tr,
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            controller: _email,
          ),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'phone'.tr,
            hint: 'phone_number_2'.tr,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            controller: _phone,
          ),
          SizedBox(height: 16.h),
          LokTextField(
              label: 'subject'.tr,
              hint: 'what_is_this_about'.tr,
              icon: Icons.subject,
              controller: _subject),
          SizedBox(height: 16.h),
          LokTextField(label: 'message'.tr, hint: 'your_message'.tr, maxLines: 5, controller: _message),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? SizedBox(
                    width: 20.r,
                    height: 20.r,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('send_message'.tr),
          ),
          SizedBox(height: 24.h),
          _info(context, Icons.mail_outline, 'support@lokinter.com'),
          SizedBox(height: 10.h),
          _info(context, Icons.phone_outlined, '+216 70 000 000'),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: AppPalette.primary),
        SizedBox(width: 10.w),
        Text(text, style: TextStyle(fontSize: 13.sp, color: cs.onSurface)),
      ],
    );
  }
}
