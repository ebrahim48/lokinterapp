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
      toast('Name, email and message are required');
      return;
    }
    if (!isValidEmail(_email.text)) {
      toast('That email address does not look right');
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
      toast('Message sent — the team will get back to you');
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
      appBar: AppBar(title: const Text('Contact us')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        children: [
          Text("We'd love to hear from you",
              style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 6.h),
          Text('Send us a message and the team will get back to you.',
              style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
          SizedBox(height: 22.h),
          LokTextField(
              label: 'Name', hint: 'your name', icon: Icons.person_outline, controller: _name),
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
          LokTextField(
              label: 'Subject',
              hint: 'what is this about?',
              icon: Icons.subject,
              controller: _subject),
          SizedBox(height: 16.h),
          LokTextField(label: 'Message', hint: 'your message', maxLines: 5, controller: _message),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? SizedBox(
                    width: 20.r,
                    height: 20.r,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Send message'),
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
