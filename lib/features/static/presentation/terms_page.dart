import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/widgets/simple_html.dart';
import '../../lookups/data/lookups_repository.dart';

/// Legal pages come from the CMS (`/lookups/getPages`) — same source the
/// website renders, translated server-side off the X-Lang header. [slug]
/// picks which document: termsConditions (default) or privacyPolicy. The
/// bundled fallback keeps the screen useful offline on first launch.
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
  bool _failed = false;

  bool get _isPrivacy => widget.slug == 'privacyPolicy';

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

  Future<void> _load({bool forceRefresh = false}) async {
    if (mounted && !forceRefresh) setState(() => _loading = true);
    try {
      final pages = await LookupsRepository().pages(forceRefresh: forceRefresh);
      final page = pages[widget.slug];
      if (!mounted) return;
      setState(() {
        if (page is Map) {
          _title = _humanTitle(page['title']?.toString(), page['slug']?.toString());
          _content = page['content']?.toString();
        }
        _failed = page is! Map;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// The CMS sometimes stores the title as the slug itself
  /// ("terms-and-conditions") — that is no page heading, so fall back to the
  /// app's own localized name in that case.
  String? _humanTitle(String? title, String? slug) {
    final t = title?.trim();
    if (t == null || t.isEmpty) return null;
    if (t == slug || (t.contains('-') && !t.contains(' '))) return null;
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasContent = SimpleHtml.hasText(_content);
    return Scaffold(
      appBar: AppBar(
        title: Text(_title ?? (_isPrivacy ? 'privacy.title'.tr : 'terms.title'.tr)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(forceRefresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                children: [
                  // nothing from the CMS — say so, then still show the bundled
                  // copy underneath so the screen is never blank
                  if (!hasContent && _failed) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text('legal.offlineCopy'.tr,
                              style: TextStyle(fontSize: 12.sp, color: cs.error)),
                        ),
                        TextButton(
                          onPressed: () => _load(forceRefresh: true),
                          child: Text('common.retry'.tr),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                  ],
                  if (hasContent)
                    SimpleHtml(_content!)
                  else ...[
                    Text('last_updated_june_2026'.tr,
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
            ),
    );
  }
}
