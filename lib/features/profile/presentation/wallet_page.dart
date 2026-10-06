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
  /// Default (or first) payout method — named on the payout-account card.
  PayoutMethod? _payoutMethod;

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
      // the card only names the method; a failure here mustn't fail the wallet
      final methods = await _repo.payoutMethods().catchError((_) => <PayoutMethod>[]);
      if (!mounted) return;
      setState(() {
        _data = data;
        _payoutMethod = methods.isEmpty
            ? null
            : methods.firstWhere((m) => m.isDefault, orElse: () => methods.first);
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
      // a malformed payload must end in the retry state, not a spinner
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'something_went_wrong_try_again'.tr;
      });
    }
  }

  /// The requested amount leaves Available and sits in Pending Withdrawal
  /// straight away; the reload that follows replaces this with the server's
  /// figures.
  void _reserve(double amount) {
    final d = _data;
    if (d == null || !mounted) return;
    setState(() {
      _data = WalletData(
        walletBalance: (d.displayBalance - amount).clamp(0, double.infinity),
        withdrawable: (d.displayBalance - amount).clamp(0, double.infinity),
        available: d.available,
        pendingEarnings: d.pendingEarnings,
        onHold: d.onHold,
        pendingWithdrawal: d.pendingWithdrawal + amount,
        totalPending: d.totalPending,
        lifetimeEarnings: d.lifetimeEarnings,
        currency: d.currency,
        hasStripeConnect: d.hasStripeConnect,
        potential: d.potential,
        onHoldEarnings: d.onHoldEarnings,
        disputes: d.disputes,
      );
    });
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
                      if (_data!.potential.isEmpty &&
                          _data!.onHoldEarnings.isEmpty &&
                          _data!.disputes.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: Text('no_earnings_yet_completed_deliveries_land_here'.tr,
                              style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant)),
                        ),
                      // every amount still owed, each with why it is held —
                      // none of this counts toward the available balance
                      // frozen by an open dispute — waiting for the resolution
                      for (final e in _data!.onHoldEarnings)
                        _pendingRow(context, _data!.currency, e),
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
          Icon(e.onHold ? Icons.lock_outline : Icons.hourglass_bottom,
              size: 18.sp, color: AppPalette.primary),
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
                  e.reasonLabel,
                  style: TextStyle(
                      fontSize: 12.sp,
                      color: e.onHold ? AppPalette.primary : cs.onSurfaceVariant),
                ),
                SizedBox(height: 4.h),
                Text(
                  [
                    if (e.dealId != 0) 'deal_number'.trParams({'id': '${e.dealId}'}),
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
                    if (d.dealId != 0) 'deal_number'.trParams({'id': '${d.dealId}'}),
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
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Top: primary available balance — the only withdrawable amount
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.r),
              topRight: Radius.circular(20.r),
            ),
            gradient: const LinearGradient(
              colors: [AppPalette.primary, Color(0xFF8E3F3C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('available_balance'.tr,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 12.sp)),
              SizedBox(height: 6.h),
              Text(
                '${data.currency} ${data.displayBalance.toStringAsFixed(2)}',
                style: TextStyle(
                    color: Colors.white, fontSize: 30.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4.h),
              Text(
                'only_available_balance_can_be_withdrawn'.tr,
                style:
                    TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.sp),
              ),
              SizedBox(height: 16.h),
              GestureDetector(
                onTap: _openWithdraw,
                child: _miniBtn(context, Icons.arrow_outward, 'withdraw'.tr),
              ),
            ],
          ),
        ),
        // Bottom: 3 secondary sections in a row
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20.r),
              bottomRight: Radius.circular(20.r),
            ),
          ),
          child: Row(
            children: [
              _balanceSection(
                context,
                label: 'pending_earnings'.tr,
                amount: data.pendingEarnings,
                currency: data.currency,
                icon: Icons.hourglass_bottom,
                iconColor: Colors.orange,
                tooltip: 'pending_earnings_hint'.tr,
                dividerRight: true,
              ),
              _balanceSection(
                context,
                label: 'on_hold'.tr,
                amount: data.onHold,
                currency: data.currency,
                icon: Icons.lock_outline,
                iconColor: AppPalette.primary,
                tooltip: 'on_hold_hint'.tr,
                dividerRight: true,
              ),
              _balanceSection(
                context,
                label: 'pending_withdrawal'.tr,
                amount: data.pendingWithdrawal,
                currency: data.currency,
                icon: Icons.schedule_send_outlined,
                iconColor: cs.onSurfaceVariant,
                tooltip: 'pending_withdrawal_hint'.tr,
                dividerRight: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _balanceSection(
    BuildContext context, {
    required String label,
    required double amount,
    required String currency,
    required IconData icon,
    required Color iconColor,
    required String tooltip,
    required bool dividerRight,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
          decoration: BoxDecoration(
            border: dividerRight
                ? Border(right: BorderSide(color: cs.outline))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13.sp, color: iconColor),
                  SizedBox(width: 4.w),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 9.5.sp,
                          color: cs.onSurfaceVariant,
                          height: 1.3),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                '$currency ${amount.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: amount > 0 ? cs.onSurface : cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns the translated tooltip text, falling back to [fallback] when the
  /// translation key is missing (i.e. the translation equals the raw key).
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
        availableBalance: _data?.displayBalance ?? 0,
        onDone: (amount) {
          _reserve(amount);
          return _load();
        },
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
                  _payoutMethod != null
                      ? _payoutMethod!.label
                      : data.hasStripeConnect
                          ? 'stripe_connected'.tr
                          : 'no_payout_method_linked'.tr,
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
  final double availableBalance;
  /// Called with the requested amount once the server accepts it.
  final Future<void> Function(double amount) onDone;

  const _WithdrawSheet({
    required this.currency,
    required this.availableBalance,
    required this.onDone,
  });

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _repo = WalletRepository();
  final _amount = TextEditingController();

  // label shown in the dropdown → method; labels are made unique so two
  // accounts of the same kind can't collide (the dropdown asserts on that)
  Map<String, PayoutMethod> _methods = {};
  bool _methodsLoading = true;
  bool _methodsError = false;
  String? _method;
  bool _sending = false;

  // live fee preview (website: quote before submit)
  PayoutQuote? _quote;
  bool _quoting = false;

  // digits with at most two decimals — rejects letters, signs, "NaN",
  // "Infinity" and exponents that double.tryParse would otherwise accept
  static final _amountPattern = RegExp(r'^\d+([.,]\d{0,2})?$');

  PayoutMethod? get _selected => _method == null ? null : _methods[_method];
  bool get _isWise => _selected?.type == 'WISE';

  /// The typed amount, or null when it isn't a valid money value.
  double? get _parsedAmount {
    final text = _amount.text.trim();
    if (!_amountPattern.hasMatch(text)) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }

  /// Minimum withdrawal allowed for the currently selected method.
  double get _minimumAmount => switch (_selected?.type) {
        'WISE' => 50.0,
        'STRIPE' => 10.0,
        'PAYPAL' => 10.0,
        _ => 0.0,
      };

  /// Why the current input can't be submitted, or null when it can.
  /// Empty input returns null too — there's nothing to complain about yet.
  String? get _amountError {
    if (_amount.text.trim().isEmpty) return null;
    final amount = _parsedAmount;
    if (amount == null) return 'enter_a_valid_withdrawal_amount'.tr;
    if (amount <= 0) return 'enter_a_valid_withdrawal_amount'.tr;
    if (amount > widget.availableBalance) {
      return 'amount_exceeds_available_balance'.tr;
    }
    if (_minimumAmount > 0 && amount < _minimumAmount) {
      return 'minimum_withdrawal'.trParams(
          {'amount': '${widget.currency} ${_minimumAmount.toStringAsFixed(2)}'});
    }
    return null;
  }

  bool get _canSubmit =>
      !_sending && _selected != null && _parsedAmount != null && _amountError == null;

  @override
  void initState() {
    super.initState();
    _loadMethods();
    // Rebuild on every keystroke so inline errors and the submit button
    // disable state reflect the current input instantly.
    _amount.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
    _refreshQuote();
  }

  Future<void> _loadMethods() async {
    setState(() {
      _methodsLoading = true;
      _methodsError = false;
    });
    try {
      // 15-second timeout so the sheet never loads indefinitely.
      final list = await _repo
          .payoutMethods()
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final byLabel = <String, PayoutMethod>{};
      for (final m in list) {
        var label = m.label.isEmpty ? m.type : m.label;
        for (var n = 2; byLabel.containsKey(label); n++) {
          label = '${m.label} ($n)';
        }
        byLabel[label] = m;
      }
      setState(() {
        _methods = byLabel;
        _methodsLoading = false;
        // preselect the default account, like the website does
        _method ??= byLabel.entries
            .where((e) => e.value.isDefault)
            .map((e) => e.key)
            .firstOrNull;
      });
    } catch (_) {
      // Covers AppException, TimeoutException and malformed payloads
      if (!mounted) return;
      setState(() {
        _methodsLoading = false;
        _methodsError = true;
      });
    }
  }

  @override
  void dispose() {
    _amount.removeListener(_onAmountChanged);
    _amount.dispose();
    super.dispose();
  }

  Future<void> _refreshQuote() async {
    final amount = _parsedAmount;
    final method = _selected;
    // Wise fees are unknown in advance — the disclaimer replaces the quote
    if (amount == null || amount <= 0 || method == null || _isWise) {
      if (_quote != null && mounted) setState(() => _quote = null);
      return;
    }
    setState(() => _quoting = true);
    try {
      final q = await _repo.quotePayout(method.id, amount, widget.currency);
      if (mounted && _parsedAmount == amount && _selected == method) {
        setState(() => _quote = q);
      }
    } catch (_) {
      if (mounted) setState(() => _quote = null);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _submit() async {
    final amount = _parsedAmount;
    final method = _selected;
    if (method == null) {
      toast('pick_a_payout_method_and_an_amount'.tr);
      return;
    }
    if (amount == null || amount <= 0) {
      toast('enter_a_valid_withdrawal_amount'.tr);
      return;
    }
    final error = _amountError;
    if (error != null) {
      toast(error);
      return;
    }
    setState(() => _sending = true);
    try {
      await _repo.requestPayout(method.id, amount, widget.currency);
      if (!mounted) return;
      Navigator.pop(context);
      toast('withdrawal_requested'.tr);
      widget.onDone(amount);
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final error = _amountError;
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
                'available_amount'.trParams({
                  'amount': '${widget.currency} ${widget.availableBalance.toStringAsFixed(2)}'
                }),
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.primary),
              ),
              SizedBox(height: 4.h),
              Text(
                _methodsLoading
                    ? 'loading_payout_methods'.tr
                    : _methodsError
                        ? 'could_not_load_payout_methods_retry'.tr
                        : _methods.isEmpty
                            ? 'no_payout_methods_yet_add_one_so_you_can_withdra'.tr
                            : _method == null
                                ? 'withdraw_minimums'.trParams({'currency': widget.currency})
                                : 'withdraw_min_max'.trParams({
                                    'min': '${widget.currency} ${_minimumAmount.toStringAsFixed(2)}',
                                    'max': '${widget.currency} ${widget.availableBalance.toStringAsFixed(2)}',
                                  }),
                style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant, height: 1.4),
              ),
              if (_methodsError) ...[
                SizedBox(height: 8.h),
                TextButton(
                  onPressed: _loadMethods,
                  child: Text('retry'.tr),
                ),
              ],
              SizedBox(height: 18.h),
              if (_methodsLoading)
                const Center(child: CircularProgressIndicator())
              else if (!_methodsError) ...[
                LokDropdownField(
                  label: 'payout_method'.tr,
                  hint: 'where_the_money_goes'.tr,
                  icon: Icons.account_balance_outlined,
                  options: _methods.keys.toList(),
                  value: _method,
                  onChanged: (v) {
                    setState(() {
                      _method = v;
                      _quote = null;
                    });
                    _refreshQuote();
                  },
                ),
                SizedBox(height: 14.h),
                LokTextField(
                  label: 'amount_in_currency'.trParams({'currency': widget.currency}),
                  hint: _minimumAmount > 0
                      ? 'min_amount'.trParams({'amount': _minimumAmount.toStringAsFixed(2)})
                      : 'e_g_50'.tr,
                  icon: Icons.payments_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  controller: _amount,
                ),
                if (error != null) ...[
                  SizedBox(height: 6.h),
                  Text(
                    error,
                    style: TextStyle(fontSize: 11.sp, color: AppPalette.primary),
                  ),
                ],
                if (_isWise) ...[
                  SizedBox(height: 10.h),
                  _note(cs, 'wise_fee_disclaimer'.tr),
                ] else if (_quoting || _quote != null) ...[
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
                                  style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
                            ],
                          )
                        : _feeText(cs),
                  ),
                ],
                SizedBox(height: 18.h),
                ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: _sending
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('request_withdrawal'.tr),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _note(ColorScheme cs, String text) => Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 14.sp, color: cs.onSurfaceVariant),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 12.5.sp, color: cs.onSurface, height: 1.4)),
            ),
          ],
        ),
      );

  /// Fee breakdown for methods with a known fee. Wise never reaches here —
  /// its fee is variable and deducted by Wise, so it gets the disclaimer.
  Widget _feeText(ColorScheme cs) {
    final q = _quote!;
    if (!q.showFeeAmount) {
      // backend says the fee is variable — show its message, never "Fee: 0"
      return Text(
        q.message ?? 'transfer_fees_may_apply'.tr,
        style: TextStyle(fontSize: 12.5.sp, color: cs.onSurface, height: 1.4),
      );
    }

    if (q.feeAmount == 0) {
      return Text(
        'no_fee_you_receive'.trParams(
            {'amount': '${widget.currency} ${q.netAmount.toStringAsFixed(2)}'}),
        style: TextStyle(
            fontSize: 12.5.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
      );
    }

    return Text(
      'fee_you_receive'.trParams({
        'fee': '${widget.currency} ${q.feeAmount.toStringAsFixed(2)}',
        'amount': '${widget.currency} ${q.netAmount.toStringAsFixed(2)}',
      }),
      style: TextStyle(
          fontSize: 12.5.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
    );
  }
}
