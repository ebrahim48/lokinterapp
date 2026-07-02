import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/lok_fields.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

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
          const LokTextField(label: 'Name', hint: 'your name', icon: Icons.person_outline),
          SizedBox(height: 16.h),
          const LokTextField(
            label: 'Email',
            hint: 'you@email.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 16.h),
          const LokTextField(label: 'Subject', hint: 'what is this about?', icon: Icons.subject),
          SizedBox(height: 16.h),
          const LokTextField(label: 'Message', hint: 'your message', maxLines: 5),
          SizedBox(height: 20.h),
          ElevatedButton(onPressed: () {}, child: const Text('Send message')),
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
