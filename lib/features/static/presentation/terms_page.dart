import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  static const _sections = [
    ('1. Using Lokinter',
        'Lokinter connects senders with travelers who carry parcels locally and '
            'internationally. By using the app you agree to act honestly and follow '
            'local laws on what can be shipped.'),
    ('2. Posting trips and requests',
        'You are responsible for the accuracy of the trips and delivery requests you '
            'post, including dates, weights, and prices. Misleading posts may be removed.'),
    ('3. Agreements and payments',
        'Deals are confirmed by both parties before any item is carried. Payments and '
            'profits are handled through the in-app wallet and supported providers.'),
    ('4. Prohibited items',
        'You may not send illegal, dangerous, or restricted goods. Travelers may refuse '
            'any item they are not comfortable carrying.'),
    ('5. Disputes',
        'If something goes wrong, open a dispute from the deal screen. Our support team '
            'reviews the evidence from both sides before making a decision.'),
    ('6. Privacy',
        'We process your data to operate the service. See the Privacy Policy for how your '
            'information is stored and used.'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & conditions')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        children: [
          Text('Last updated June 2026',
              style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
          SizedBox(height: 18.h),
          for (final s in _sections) ...[
            Text(s.$1,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
            SizedBox(height: 6.h),
            Text(s.$2,
                style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.6)),
            SizedBox(height: 18.h),
          ],
        ],
      ),
    );
  }
}
