import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../lookups/data/lookups_repository.dart';

/// Legal pages come from the CMS (`/lookups/getPages`) — same source the
/// website renders. [slug] picks which document: termsConditions (default)
/// or privacyPolicy. The bundled fallback keeps the screen useful offline
/// on first launch.
class TermsPage extends StatefulWidget {
  final String slug; // termsConditions | privacyPolicy
  const TermsPage({super.key, this.slug = 'termsConditions'});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  String? _title;
  String? _content;
  bool _loading = true;

  static const _fallbackSections = [
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
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pages = await LookupsRepository().pages();
      final page = pages[widget.slug];
      if (!mounted) return;
      setState(() {
        if (page is Map) {
          _title = page['title']?.toString();
          _content = page['content']?.toString();
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // CMS content is HTML — strip tags into readable paragraphs so it
  // renders in the app's own typography without a webview.
  String _plainText(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>|</h[1-6]>|</li>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPrivacy = widget.slug == 'privacyPolicy';
    return Scaffold(
      appBar: AppBar(
        title: Text(_title ?? (isPrivacy ? 'Privacy policy' : 'Terms & conditions')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
              children: [
                if (_content != null && _content!.trim().isNotEmpty)
                  Text(_plainText(_content!),
                      style:
                          TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.6))
                else ...[
                  Text('Last updated June 2026',
                      style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
                  SizedBox(height: 18.h),
                  for (final s in _fallbackSections) ...[
                    Text(s.$1,
                        style: TextStyle(
                            fontSize: 15.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                    SizedBox(height: 6.h),
                    Text(s.$2,
                        style: TextStyle(
                            fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.6)),
                    SizedBox(height: 18.h),
                  ],
                ],
              ],
            ),
    );
  }
}
