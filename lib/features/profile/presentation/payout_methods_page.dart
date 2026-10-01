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
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      // Apply a 15-second timeout so the page never loads indefinitely.
      // If the API hangs, we surface an error with a Retry button instead.
      final list = await _repo.payoutMethods()
          .timeout(const Duration(seconds: 15));
      StripeConnectStatus? stripe;
      try {
        stripe = await _repo.stripeStatus()
            .timeout(const Duration(seconds: 10));
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
    } catch (_) {
      // Covers TimeoutException and any unexpected network error
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'could_not_load_payout_methods_retry'.tr;
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
        toast('stripe_onboarding_is_not_available_right_now'.tr);
        return;
      }
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) {
        toast('could_not_open_stripe_onboarding'.tr);
        return;
      }
      toast('finish_onboarding_in_the_browser_then_pull_to_re'.tr);
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addPaypal() {
    final email = TextEditingController();
    _sheet(
      title: 'add_paypal'.tr,
      fields: [
        LokTextField(
          label: 'paypal_email'.tr,
          hint: 'you_email_com'.tr,
          icon: Icons.mail_outline,
          required: true,
          keyboardType: TextInputType.emailAddress,
          controller: email,
        ),
      ],
      onSubmit: () {
        if (!isValidEmail(email.text)) {
          toast('enter_a_valid_paypal_email'.tr);
          return false;
        }
        _run(() => _repo.addPaypal(email.text.trim()), 'paypal_added'.tr);
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
      title: 'add_bank_wise'.tr,
      fields: [
        LokTextField(
          label: 'account_holder'.tr,
          hint: 'name_on_the_account'.tr,
          icon: Icons.person_outline,
          required: true,
          controller: name,
        ),
        SizedBox(height: 14.h),
        LokTextField(
          label: 'account_number_iban'.tr,
          hint: 'e_g_tn59_1000_6035'.tr,
          icon: Icons.numbers,
          required: true,
          controller: iban,
        ),
        SizedBox(height: 14.h),
        LokTextField(
          label: 'swift_bic'.tr,
          hint: '8_or_11_characters'.tr,
          icon: Icons.qr_code_2,
          required: true,
          controller: swift,
        ),
        SizedBox(height: 14.h),
        LokTextField(
          label: 'beneficiary_country'.tr,
          hint: 'e_g_tunisia'.tr,
          icon: Icons.public,
          required: true,
          controller: country,
        ),
        SizedBox(height: 14.h),
        LokTextField(
          label: 'bank_address'.tr,
          hint: 'branch_address'.tr,
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
          toast('all_bank_fields_are_required'.tr);
          return false;
        }
        if (ibanText.length < 4 || ibanText.length > 34) {
          toast('check_the_account_number_iban'.tr);
          return false;
        }
        if (swiftText.length != 8 && swiftText.length != 11) {
          toast('swift_bic_must_be_8_or_11_characters'.tr);
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
          'bank_account_added_review'.tr,
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
                  child: Text('save'.tr),
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
        title: Text('remove_payout_method'.tr),
        content: Text('method_no_longer_receives'.trParams({'method': m.label})),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              Get.back();
              _run(() => _repo.removeMethod(m.id), 'payout_method_removed'.tr);
            },
            child: Text('remove'.tr, style: TextStyle(color: AppPalette.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('payout_methods'.tr)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                      TextButton(onPressed: _load, child: Text('retry'.tr)),
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
                            'no_payout_methods_yet_add_one_so_you_can_withdra'.tr,
                            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                          ),
                        ),
                      for (final m in _methods) _methodTile(context, m),
                      SizedBox(height: 20.h),
                      Text('add_a_method'.tr,
                          style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      SizedBox(height: 10.h),
                      _addTile(
                          context,
                          Icons.bolt,
                          _stripe?.status == 'active'
                              ? 'stripe_dashboard'.tr
                              : _stripe?.status == 'onboarding'
                                  ? 'resume_stripe_onboarding'.tr
                                  : 'connect_stripe'.tr,
                          _stripe?.status == 'active'
                              ? 'stripe_connected_open_dashboard'.tr
                              : 'stripe_fastest_payouts'.tr,
                          _busy ? null : _linkStripe),
                      // PayPal is off unless the server enables it
                      if (WalletRepository.paypalEnabled)
                        _addTile(context, Icons.account_balance_wallet_outlined,
                            'add_paypal'.tr, 'min_10'.tr, _busy ? null : _addPaypal),
                      _addTile(context, Icons.account_balance_outlined, 'add_bank_wise'.tr,
                          'wise_min_reviewed'.tr, _busy ? null : _addWise),
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
                  Text('default'.tr,
                      style: TextStyle(fontSize: 11.sp, color: AppPalette.verified)),
                ],
              ],
            ),
          ),
          if (!m.isDefault)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() => _repo.setDefaultMethod(m.id), 'default_updated'.tr),
              child: Text('set_default'.tr, style: TextStyle(fontSize: 11.sp)),
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
