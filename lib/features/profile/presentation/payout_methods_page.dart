import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/notify.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/lok_fields.dart';
import '../data/wallet_repository.dart';

// Where withdrawals land. Stripe onboards on a hosted page; PayPal and Wise
// are added inline.
class PayoutMethodsPage extends StatefulWidget {
  const PayoutMethodsPage({super.key});

  @override
  State<PayoutMethodsPage> createState() => _PayoutMethodsPageState();
}

class _PayoutMethodsPageState extends State<PayoutMethodsPage> {
  final _repo = WalletRepository();

  List<PayoutMethod> _methods = [];
  StripeConnectStatus? _stripe;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.payoutMethods();
      StripeConnectStatus? stripe;
      try {
        stripe = await _repo.stripeStatus();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _methods = list;
        _stripe = stripe;
        _loading = false;
        _error = null;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      toast(done);
      await _load();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Stripe Connect: active accounts jump to their Express dashboard,
  // everyone else gets the hosted onboarding page (system browser) —
  // same branching the website's payout-accounts view does.
  Future<void> _linkStripe() async {
    setState(() => _busy = true);
    try {
      if (_stripe?.status == 'active') {
        final dash = await _repo.stripeDashboardLink();
        if (dash != null) {
          await launchUrl(Uri.parse(dash), mode: LaunchMode.externalApplication);
          // register the connected account as a payout method if missing
          try {
            await _repo.linkStripe();
            await _load();
          } catch (_) {}
          return;
        }
      }
      final url = await _repo.stripeOnboardingLink();
      if (url == null) {
        toast('Stripe onboarding is not available right now');
        return;
      }
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) {
        toast('Could not open Stripe onboarding');
        return;
      }
      toast('Finish onboarding in the browser, then pull to refresh here');
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addPaypal() {
    final email = TextEditingController();
    _sheet(
      title: 'Add PayPal',
      fields: [
        LokTextField(
          label: 'PayPal email',
          hint: 'you@email.com',
          icon: Icons.mail_outline,
          required: true,
          keyboardType: TextInputType.emailAddress,
          controller: email,
        ),
      ],
      onSubmit: () {
        if (!isValidEmail(email.text)) {
          toast('Enter a valid PayPal email');
          return false;
        }
        _run(() => _repo.addPaypal(email.text.trim()), 'PayPal added');
        return true;
      },
    );
  }

  // Wise wants full banking coordinates (website's form): holder, IBAN,
  // SWIFT/BIC, beneficiary country, and the bank's address.
  void _addWise() {
    final name = TextEditingController();
    final iban = TextEditingController();
    final swift = TextEditingController();
    final country = TextEditingController();
    final bankAddress = TextEditingController();
    _sheet(
      title: 'Add bank (Wise)',
      fields: [
        LokTextField(
          label: 'Account holder',
          hint: 'name on the account',
          icon: Icons.person_outline,
          required: true,
          controller: name,
        ),
        SizedBox(height: 14.h),
        LokTextField(
          label: 'Account number / IBAN',
          hint: 'e.g. TN59 1000 6035...',
          icon: Icons.numbers,
          required: true,
          controller: iban,
        ),
        SizedBox(height: 14.h),
        LokTextField(
          label: 'SWIFT / BIC',
          hint: '8 or 11 characters',
          icon: Icons.qr_code_2,
          required: true,
          controller: swift,
        ),
        SizedBox(height: 14.h),
        LokTextField(
          label: 'Beneficiary country',
          hint: 'e.g. Tunisia',
          icon: Icons.public,
          required: true,
          controller: country,
        ),
        SizedBox(height: 14.h),
        LokTextField(
          label: 'Bank address',
          hint: 'branch address',
          icon: Icons.location_on_outlined,
          required: true,
          maxLines: 2,
          controller: bankAddress,
        ),
      ],
      onSubmit: () {
        final ibanText = iban.text.replaceAll(' ', '');
        final swiftText = swift.text.trim().toUpperCase();
        if (name.text.trim().isEmpty ||
            country.text.trim().isEmpty ||
            bankAddress.text.trim().isEmpty) {
          toast('All bank fields are required');
          return false;
        }
        if (ibanText.length < 4 || ibanText.length > 34) {
          toast('Check the account number / IBAN');
          return false;
        }
        if (swiftText.length != 8 && swiftText.length != 11) {
          toast('SWIFT / BIC must be 8 or 11 characters');
          return false;
        }
        _run(
          () => _repo.addWise(
            accountHolderName: name.text.trim(),
            accountNumber: ibanText,
            swiftBic: swiftText,
            beneficiaryCountry: country.text.trim(),
            bankAddress: bankAddress.text.trim(),
          ),
          'Bank account added — our team will review it',
        );
        return true;
      },
    );
  }

  void _sheet({
    required String title,
    required List<Widget> fields,
    required bool Function() onSubmit,
  }) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 22.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
                SizedBox(height: 16.h),
                ...fields,
                SizedBox(height: 18.h),
                ElevatedButton(
                  onPressed: () {
                    if (onSubmit()) Navigator.pop(sheetContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmRemove(PayoutMethod m) {
    Get.dialog(
      AlertDialog(
        title: const Text('Remove payout method?'),
        content: Text('${m.label} will no longer receive withdrawals.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              _run(() => _repo.removeMethod(m.id), 'Payout method removed');
            },
            child: const Text('Remove', style: TextStyle(color: AppPalette.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Payout methods')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                    children: [
                      if (_methods.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.h),
                          child: Text(
                            'No payout methods yet — add one so you can withdraw earnings.',
                            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                          ),
                        ),
                      for (final m in _methods) _methodTile(context, m),
                      SizedBox(height: 20.h),
                      Text('Add a method',
                          style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      SizedBox(height: 10.h),
                      _addTile(
                          context,
                          Icons.bolt,
                          _stripe?.status == 'active'
                              ? 'Stripe dashboard'
                              : _stripe?.status == 'onboarding'
                                  ? 'Resume Stripe onboarding'
                                  : 'Connect Stripe',
                          _stripe?.status == 'active'
                              ? 'Connected — open your Express dashboard'
                              : 'Fastest payouts, min \$10',
                          _busy ? null : _linkStripe),
                      _addTile(context, Icons.account_balance_wallet_outlined, 'Add PayPal',
                          'Min \$10', _busy ? null : _addPaypal),
                      _addTile(context, Icons.account_balance_outlined, 'Add bank (Wise)',
                          'Min \$50, reviewed by our team', _busy ? null : _addWise),
                    ],
                  ),
                ),
    );
  }

  Widget _methodTile(BuildContext context, PayoutMethod m) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_outlined, size: 20.sp, color: cs.onSurfaceVariant),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.label,
                    style: TextStyle(
                        fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.onSurface)),
                if (m.isDefault) ...[
                  SizedBox(height: 2.h),
                  Text('Default',
                      style: TextStyle(fontSize: 11.sp, color: AppPalette.verified)),
                ],
              ],
            ),
          ),
          if (!m.isDefault)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() => _repo.setDefaultMethod(m.id), 'Default updated'),
              child: Text('Set default', style: TextStyle(fontSize: 11.sp)),
            ),
          IconButton(
            onPressed: _busy ? null : () => _confirmRemove(m),
            icon: Icon(Icons.delete_outline, size: 20.sp, color: AppPalette.primary),
          ),
        ],
      ),
    );
  }

  Widget _addTile(
      BuildContext context, IconData icon, String title, String subtitle, VoidCallback? onTap) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: cs.outline),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppPalette.primary, size: 22.sp),
        title: Text(title, style: TextStyle(fontSize: 13.5.sp, color: cs.onSurface)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
        trailing: Icon(Icons.chevron_right, size: 20.sp, color: cs.onSurfaceVariant),
      ),
    );
  }
}
