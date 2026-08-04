import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/notify.dart';
import '../../../core/widgets/lok_fields.dart';
import '../data/wallet_repository.dart';
import 'payout_methods_page.dart';
import 'wallet_activity_page.dart';
import '../../../core/services/data_bus.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _repo = WalletRepository();
  WalletData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // a write elsewhere invalidates this list
    _busSub = DataBus.on({DataTopic.wallet, DataTopic.deals}).listen((_) => _load());
  }

  StreamSubscription<DataTopic>? _busSub;

  @override
  void dispose() {
    _busSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.dashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('wallet_payouts'.tr)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                      TextButton(onPressed: _load, child: Text('retry'.tr)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                    children: [
                      _balanceCard(context, _data!),
                      SizedBox(height: 22.h),
                      _payoutAccount(context, _data!),
                      SizedBox(height: 22.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('recent_activity'.tr,
                              style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface)),
                          TextButton(
                            onPressed: () => Get.to(() => const WalletActivityPage()),
                            child: Text('see_all_2'.tr),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      if (_data!.potential.isEmpty && _data!.disputes.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: Text('no_earnings_yet_completed_deliveries_land_here'.tr,
                              style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant)),
                        ),
                      // every amount still owed, each with why it is held —
                      // none of this counts toward the available balance
                      for (final e in _data!.potential)
                        _pendingRow(context, _data!.currency, e),
                      for (final d in _data!.disputes)
                        _disputeRow(context, _data!.currency, d),
                    ],
                  ),
                ),
    );
  }

  // One line of potential profit: the amount, why it is not withdrawable yet,
  // which deal it belongs to, and any countdown still running.
  Widget _pendingRow(BuildContext context, String currency, WalletEarning e) {
    final cs = Theme.of(context).colorScheme;
    final countdown = e.countdownText;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_bottom, size: 18.sp, color: AppPalette.primary),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$currency ${e.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface),
                ),
                SizedBox(height: 2.h),
                Text(
                  e.statusLabel,
                  style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
                ),
                SizedBox(height: 4.h),
                Text(
                  [
                    if (e.dealRef.isNotEmpty) e.dealRef else 'Deal #${e.dealId}',
                    if (countdown != null) countdown,
                  ].join('  •  '),
                  style: TextStyle(fontSize: 10.5.sp, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // A guarantee charged or held because of a dispute, with the reason.
  Widget _disputeRow(BuildContext context, String currency, WalletDispute d) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppPalette.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gpp_maybe_outlined, size: 18.sp, color: AppPalette.primary),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$currency ${d.amountCharged.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface)),
                SizedBox(height: 2.h),
                Text(d.statusLabel,
                    style: TextStyle(fontSize: 12.sp, color: AppPalette.primary)),
                if (d.reason.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(d.reason,
                      style:
                          TextStyle(fontSize: 11.5.sp, color: cs.onSurfaceVariant)),
                ],
                SizedBox(height: 4.h),
                Text(
                  [
                    if (d.dealRef.isNotEmpty) d.dealRef else 'Deal #${d.dealId}',
                    if (d.status.isNotEmpty) d.status,
                  ].join('  •  '),
                  style: TextStyle(fontSize: 10.5.sp, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(BuildContext context, WalletData data) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: const LinearGradient(
          colors: [AppPalette.primary, Color(0xFF8E3F3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('available_earnings'.tr,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.sp)),
          SizedBox(height: 6.h),
          Text('${data.currency} ${data.available.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.white, fontSize: 30.sp, fontWeight: FontWeight.w800)),
          if (data.totalPending > 0) ...[
            SizedBox(height: 4.h),
            Text('${data.currency} ${data.totalPending.toStringAsFixed(2)} pending release',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.sp)),
          ],
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: _openWithdraw,
            child: _miniBtn(context, Icons.arrow_outward, 'Withdraw'),
          ),
        ],
      ),
    );
  }

  void _openWithdraw() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (_) => _WithdrawSheet(
        currency: _data?.currency ?? 'USD',
        onDone: _load,
      ),
    );
  }

  Widget _miniBtn(BuildContext context, IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16.sp),
          SizedBox(width: 6.w),
          Text(label, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _payoutAccount(BuildContext context, WalletData data) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_outlined, color: cs.onSurfaceVariant, size: 22.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('payout_account'.tr,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.onSurface)),
                SizedBox(height: 2.h),
                Text(
                  data.hasStripeConnect ? 'Stripe connected' : 'No payout method linked yet',
                  style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await Get.to(() => const PayoutMethodsPage());
              _load(); // the linked account may have changed
            },
            child: Text('manage'.tr),
          ),
        ],
      ),
    );
  }

}

class _WithdrawSheet extends StatefulWidget {
  final String currency;
  final Future<void> Function() onDone;

  const _WithdrawSheet({required this.currency, required this.onDone});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _repo = WalletRepository();
  final _amount = TextEditingController();

  List<PayoutMethod> _methods = [];
  String? _method;
  bool _sending = false;

  // live fee preview (website: quote before submit)
  PayoutQuote? _quote;
  bool _quoting = false;

  @override
  void initState() {
    super.initState();
    _repo.payoutMethods().then((list) {
      if (!mounted) return;
      setState(() => _methods = list);
    }).catchError((_) {});
    _amount.addListener(_refreshQuote);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _refreshQuote() async {
    final amount = double.tryParse(_amount.text);
    final method = _methods.firstWhereOrNull((m) => m.label == _method);
    if (amount == null || amount <= 0 || method == null) {
      if (_quote != null && mounted) setState(() => _quote = null);
      return;
    }
    setState(() => _quoting = true);
    try {
      final q = await _repo.quotePayout(method.id, amount, widget.currency);
      // ignore stale responses for an amount the user has already edited
      if (mounted && double.tryParse(_amount.text) == amount) {
        setState(() => _quote = q);
      }
    } catch (_) {
      if (mounted) setState(() => _quote = null);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text);
    final method = _methods.firstWhereOrNull((m) => m.label == _method);
    if (amount == null || method == null) {
      toast('pick_a_payout_method_and_an_amount'.tr);
      return;
    }
    setState(() => _sending = true);
    try {
      await _repo.requestPayout(method.id, amount, widget.currency);
      if (!mounted) return;
      Navigator.pop(context);
      toast('withdrawal_requested'.tr);
      widget.onDone();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('withdraw_earnings'.tr, style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: 6.h),
              Text(
                _methods.isEmpty
                    ? 'No payout methods linked yet — add one from the web dashboard first.'
                    : 'Minimums: Stripe/PayPal ${widget.currency} 10, bank ${widget.currency} 50.',
                style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant, height: 1.4),
              ),
              SizedBox(height: 18.h),
              LokDropdownField(
                label: 'payout_method'.tr,
                hint: 'where_the_money_goes'.tr,
                icon: Icons.account_balance_outlined,
                options: _methods.map((m) => m.label).toList(),
                value: _method,
                onChanged: (v) {
                  setState(() => _method = v);
                  _refreshQuote();
                },
              ),
              SizedBox(height: 14.h),
              LokTextField(
                label: 'Amount (${widget.currency})',
                hint: 'e_g_50'.tr,
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                controller: _amount,
              ),
              if (_quoting || _quote != null) ...[
                SizedBox(height: 10.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: _quoting
                      ? Row(
                          children: [
                            SizedBox(
                                width: 14.r,
                                height: 14.r,
                                child: const CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 10.w),
                            Text('calculating_fees'.tr,
                                style:
                                    TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
                          ],
                        )
                      : Text(
                          'Fee ${widget.currency} ${_quote!.feeAmount.toStringAsFixed(2)} — '
                          'you receive ${widget.currency} ${_quote!.netAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface),
                        ),
                ),
              ],
              SizedBox(height: 18.h),
              ElevatedButton(
                onPressed: _sending || _methods.isEmpty ? null : _submit,
                child: _sending
                    ? SizedBox(
                        width: 20.r,
                        height: 20.r,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('request_withdrawal'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
