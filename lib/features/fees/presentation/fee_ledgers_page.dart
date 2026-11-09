import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/fee_gate.dart';
import '../../../core/utils/notify.dart';
import '../../../core/utils/stripe_sheet.dart';
import '../data/fee_models.dart';
import '../data/fees_repository.dart';
import 'invoices_page.dart';

/// Transporter fee ledgers (REQ §9, §10 · GUIDE Screen 9): the Tunisia local
/// ledger in TND and the international ledger in USD, side by side and never
/// mixed. Each shows its unpaid balance against its threshold, its status,
/// the grace countdown once payment is required, and a way to pay — required
/// or voluntary. Paying one ledger never touches the other.
class FeeLedgersPage extends StatefulWidget {
  const FeeLedgersPage({super.key});

  @override
  State<FeeLedgersPage> createState() => _FeeLedgersPageState();
}

class _FeeLedgersPageState extends State<FeeLedgersPage> {
  final _repo = FeesRepository();
  LedgerSummary? _summary;
  String? _error;
  bool _loading = true;
  String? _paying; // currency being paid

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _repo.ledgers();
      if (!mounted) return;
      setState(() {
        _summary = s;
        _error = null;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _pay(FeeLedger ledger) async {
    if (_paying != null) return;
    setState(() => _paying = ledger.currency);
    try {
      final s = await _repo.initiateSettlement(ledger.currency);
      if (s.isStripe) {
        final ok = await presentStripeSheet(s.clientSecret!);
        if (ok) {
          toast('fee_payment_submitted'.tr);
          FeesRepository.announcePaid();
          await _afterPayment();
        }
      } else if (s.bankDetails != null) {
        if (mounted) await _showBankDetails(s);
      } else {
        toast('fee_payment_started'.tr);
        await _afterPayment();
      }
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _paying = null);
    }
  }

  // the server settles through Stripe's webhook — give it a moment, then
  // re-read both the ledgers and the profile (restrictions lift there)
  Future<void> _afterPayment() async {
    await _load();
    await FeeGate.refresh(force: true);
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    await _load();
    await FeeGate.refresh(force: true);
  }

  Future<void> _showBankDetails(Settlement s) async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('bank_transfer_details'.tr, style: Theme.of(ctx).textTheme.titleMedium),
              SizedBox(height: 6.h),
              Text('bank_transfer_hint'.trParams({'amount': formatAmount(s)}),
                  style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, height: 1.4)),
              SizedBox(height: 12.h),
              for (final e in s.bankDetails!.entries)
                if ('${e.value ?? ''}'.isNotEmpty)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_humanKey(e.key),
                        style: TextStyle(fontSize: 11.5.sp, color: cs.onSurfaceVariant)),
                    subtitle: Text('${e.value}',
                        style: TextStyle(fontSize: 13.sp, color: cs.onSurface)),
                    trailing: IconButton(
                      icon: Icon(Icons.copy, size: 16.sp),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: '${e.value}'));
                        toast('copied'.tr);
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
    await _load();
  }

  static String formatAmount(Settlement s) =>
      FeeLedger(currency: s.currency, threshold: 0, currentBalance: 0, frozenBalance: 0,
              totalDue: 0, status: LedgerStatus.active)
          .money(s.amount);

  static String _humanKey(String k) {
    final spaced = k
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return spaced.isEmpty ? k : spaced[0].toUpperCase() + spaced.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('fee_ledgers'.tr),
        actions: [
          IconButton(
            tooltip: 'invoices_tax_records'.tr,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Get.to(() => const InvoicesPage()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _load();
          await FeeGate.refresh(force: true);
        },
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _summary == null) {
      return ListView(
        padding: EdgeInsets.all(24.w),
        children: [
          SizedBox(height: 80.h),
          Icon(Icons.error_outline, size: 40.sp, color: cs.onSurfaceVariant),
          SizedBox(height: 12.h),
          Text(_error!, textAlign: TextAlign.center),
          SizedBox(height: 12.h),
          Center(child: TextButton(onPressed: _load, child: Text('retry'.tr))),
        ],
      );
    }
    final ledgers = _summary?.ledgers ?? const [];
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
      children: [
        Text('fee_ledgers_intro'.tr,
            style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant, height: 1.4)),
        SizedBox(height: 14.h),
        if (ledgers.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 40.h),
            child: Text('no_fee_ledgers_yet'.tr, textAlign: TextAlign.center),
          ),
        for (final l in ledgers) ...[
          _LedgerCard(
            ledger: l,
            paying: _paying == l.currency,
            disabled: _paying != null,
            onPay: () => _pay(l),
          ),
          SizedBox(height: 14.h),
        ],
        OutlinedButton.icon(
          onPressed: () => Get.to(() => const InvoicesPage()),
          icon: Icon(Icons.receipt_long_outlined, size: 17.sp),
          label: Text('invoices_tax_records'.tr),
        ),
      ],
    );
  }
}

class _LedgerCard extends StatelessWidget {
  final FeeLedger ledger;
  final bool paying;
  final bool disabled;
  final VoidCallback onPay;

  const _LedgerCard({
    required this.ledger,
    required this.paying,
    required this.disabled,
    required this.onPay,
  });

  (String, Color) get _status => switch (ledger.status) {
        LedgerStatus.active => ('ledger_status_active'.tr, const Color(0xFF15803D)),
        LedgerStatus.paymentRequired =>
          ('ledger_status_payment_required'.tr, const Color(0xFFD97706)),
        LedgerStatus.overdue => ('ledger_status_overdue'.tr, const Color(0xFFB91C1C)),
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = ledger;
    final (statusLabel, statusColor) = _status;
    final pct = (l.progress * 100).round();
    final breached = l.progress >= 1;
    final barColor = l.isOverdue
        ? const Color(0xFFB91C1C)
        : (breached ? const Color(0xFFD97706) : AppPalette.primary);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
            color: l.paymentRequired ? statusColor.withValues(alpha: 0.5) : cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(l.isLocal ? Icons.location_on_outlined : Icons.public,
                  size: 18.sp,
                  color: l.isLocal ? AppPalette.localAccent : AppPalette.intlAccent),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(l.title,
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'unpaid_balance_of_threshold'.trParams({
              'balance': l.money(l.totalDue),
              'threshold': l.money(l.threshold),
            }),
            style: TextStyle(fontSize: 13.sp, color: cs.onSurface),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.r),
                  child: LinearProgressIndicator(
                    value: l.progress.clamp(0, 1).toDouble(),
                    minHeight: 8.h,
                    color: barColor,
                    backgroundColor: cs.outline.withValues(alpha: 0.4),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Text(breached ? '$pct% · ${'threshold_reached'.tr}' : '$pct%',
                  style: TextStyle(
                      fontSize: 11.sp, fontWeight: FontWeight.w600, color: barColor)),
            ],
          ),
          if (l.frozenBalance > 0) ...[
            SizedBox(height: 8.h),
            Text('frozen_in_payment_request'.trParams({'amount': l.money(l.frozenBalance)}),
                style: TextStyle(fontSize: 11.5.sp, color: cs.onSurfaceVariant)),
          ],
          if (l.paymentRequired) ...[
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                l.isOverdue
                    ? 'ledger_overdue_note'.tr
                    : (l.daysLeft == null
                        ? 'payment_required_note'.tr
                        : 'payment_required_within_days'.trParams({'days': '${l.daysLeft}'})),
                style: TextStyle(fontSize: 12.sp, color: statusColor, height: 1.35),
              ),
            ),
          ],
          if (l.qualifyingCount != null) ...[
            SizedBox(height: 10.h),
            Text(
              (l.isLocal ? 'completed_deals_this_month' : 'completed_deals_90_days')
                  .trParams({'n': '${l.qualifyingCount}'}),
              style: TextStyle(fontSize: 11.5.sp, color: cs.onSurfaceVariant),
            ),
            if (l.nextRate != null && l.dealsToNextTier != null)
              Text(
                'deals_to_next_tier'.trParams({
                  'n': '${l.dealsToNextTier}',
                  'rate': l.money(double.tryParse(l.nextRate!) ?? 0),
                }),
                style: TextStyle(fontSize: 11.5.sp, color: cs.onSurfaceVariant),
              ),
          ],
          if (l.totalDue > 0) ...[
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              child: l.paymentRequired
                  ? ElevatedButton(
                      onPressed: disabled ? null : onPay,
                      child: paying
                          ? _spinner()
                          : Text('pay_required_balance'
                              .trParams({'amount': l.money(l.totalDue)})),
                    )
                  : OutlinedButton(
                      onPressed: disabled ? null : onPay,
                      child: paying ? _spinner(dark: true) : Text('pay_balance_now_voluntary'.tr),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _spinner({bool dark = false}) => SizedBox(
        width: 18.r,
        height: 18.r,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: dark ? AppPalette.primary : Colors.white),
      );
}
