import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/notify.dart';
import '../../../core/widgets/lok_fields.dart';
import '../data/wallet_repository.dart';

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
      appBar: AppBar(title: const Text('Wallet & payouts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                      TextButton(onPressed: _load, child: const Text('Retry')),
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
                      Text('Recent activity',
                          style: TextStyle(
                              fontSize: 15.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                      SizedBox(height: 8.h),
                      if (_data!.recent.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: Text('No earnings yet — completed deliveries land here.',
                              style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant)),
                        ),
                      for (final e in _data!.recent)
                        _txRow(context, e.label,
                            '+ ${_data!.currency} ${e.amount.toStringAsFixed(2)}', e.credit),
                    ],
                  ),
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
          Text('Available earnings',
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
                Text('Payout account',
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
            onPressed: () => toast('Payout methods are managed from the web dashboard for now'),
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  Widget _txRow(BuildContext context, String label, String amount, bool credit) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18.r,
            backgroundColor: (credit ? AppPalette.verified : cs.onSurfaceVariant).withValues(alpha: 0.12),
            child: Icon(
              credit ? Icons.south_west : Icons.north_east,
              size: 16.sp,
              color: credit ? AppPalette.verified : cs.onSurfaceVariant,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.sp, color: cs.onSurface)),
          ),
          Text(amount,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: credit ? AppPalette.verified : cs.onSurface,
              )),
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

  @override
  void initState() {
    super.initState();
    _repo.payoutMethods().then((list) {
      if (!mounted) return;
      setState(() => _methods = list);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text);
    final method = _methods.firstWhereOrNull((m) => m.label == _method);
    if (amount == null || method == null) {
      toast('Pick a payout method and an amount');
      return;
    }
    setState(() => _sending = true);
    try {
      await _repo.requestPayout(method.id, amount, widget.currency);
      if (!mounted) return;
      Navigator.pop(context);
      toast('Withdrawal requested');
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
              Text('Withdraw earnings', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: 6.h),
              Text(
                _methods.isEmpty
                    ? 'No payout methods linked yet — add one from the web dashboard first.'
                    : 'Minimums: Stripe/PayPal ${widget.currency} 10, bank ${widget.currency} 50.',
                style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant, height: 1.4),
              ),
              SizedBox(height: 18.h),
              LokDropdownField(
                label: 'Payout method',
                hint: 'where the money goes',
                icon: Icons.account_balance_outlined,
                options: _methods.map((m) => m.label).toList(),
                value: _method,
                onChanged: (v) => setState(() => _method = v),
              ),
              SizedBox(height: 14.h),
              LokTextField(
                label: 'Amount (${widget.currency})',
                hint: 'e.g. 50',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                controller: _amount,
              ),
              SizedBox(height: 18.h),
              ElevatedButton(
                onPressed: _sending || _methods.isEmpty ? null : _submit,
                child: _sending
                    ? SizedBox(
                        width: 20.r,
                        height: 20.r,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Request withdrawal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
