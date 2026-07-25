import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/notify.dart';
import '../../../core/widgets/lok_segmented.dart';
import '../data/wallet_repository.dart';

/// Website parity: the wallet "activity" view — the full transaction
/// ledger plus the payout-request history with statuses.
class WalletActivityPage extends StatefulWidget {
  const WalletActivityPage({super.key});

  @override
  State<WalletActivityPage> createState() => _WalletActivityPageState();
}

class _WalletActivityPageState extends State<WalletActivityPage> {
  final _repo = WalletRepository();

  int _tab = 0; // 0 transactions, 1 payout requests
  bool _loading = true;
  List<WalletTransaction> _transactions = [];
  List<PayoutRequestRow> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.transactions(),
        _repo.payoutRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _transactions = results[0] as List<WalletTransaction>;
        _requests = results[1] as List<PayoutRequestRow>;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet activity')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 4.h),
            child: LokSegmented(
              labels: const ['Transactions', 'Withdrawals'],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _tab == 0 ? _txList(cs) : _requestList(cs),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _txList(ColorScheme cs) {
    if (_transactions.isEmpty) {
      return ListView(
        padding: EdgeInsets.all(24.w),
        children: [
          Text('No transactions yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
        ],
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline),
      itemBuilder: (_, i) {
        final t = _transactions[i];
        final credit = t.isCredit;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18.r,
                backgroundColor:
                    (credit ? AppPalette.verified : cs.onSurfaceVariant).withValues(alpha: 0.12),
                child: Icon(
                  credit ? Icons.south_west : Icons.north_east,
                  size: 16.sp,
                  color: credit ? AppPalette.verified : cs.onSurfaceVariant,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.description.isEmpty ? _typeLabel(t.type) : t.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.sp, color: cs.onSurface),
                    ),
                    if (t.createdAt != null) ...[
                      SizedBox(height: 2.h),
                      Text(shortDate(t.createdAt!),
                          style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${credit ? '+' : '-'} \$${t.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: credit ? AppPalette.verified : cs.onSurface),
                  ),
                  SizedBox(height: 2.h),
                  Text('bal \$${t.balanceAfter.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _typeLabel(String type) => switch (type) {
        'credit' => 'Earning credited',
        'debit' => 'Withdrawal',
        'refund' => 'Refund',
        'reserve' => 'Amount reserved',
        'release' => 'Reserve released',
        'external_credit' => 'Top-up',
        'external_debit' => 'External payout',
        _ => type,
      };

  Widget _requestList(ColorScheme cs) {
    if (_requests.isEmpty) {
      return ListView(
        padding: EdgeInsets.all(24.w),
        children: [
          Text('No withdrawal requests yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
        ],
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      itemCount: _requests.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline),
      itemBuilder: (_, i) {
        final r = _requests[i];
        final (bg, fg) = _statusColors(r.status, cs);
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.method.toUpperCase()} — ${r.currency} ${r.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      [
                        if (r.feeAmount > 0) 'fee \$${r.feeAmount.toStringAsFixed(2)}',
                        if (r.netAmount > 0) 'net \$${r.netAmount.toStringAsFixed(2)}',
                        if (r.requestedAt != null) shortDate(r.requestedAt!),
                      ].join(' · '),
                      style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration:
                    BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20.r)),
                child: Text(_statusLabel(r.status),
                    style:
                        TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: fg)),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(String s) => switch (s) {
        'processing' => 'Processing',
        'fulfilled' => 'Paid',
        'failed' => 'Failed',
        'pending_admin_review' => 'In review',
        'approved' => 'Approved',
        'declined' => 'Declined',
        _ => s,
      };

  (Color, Color) _statusColors(String s, ColorScheme cs) => switch (s) {
        'fulfilled' || 'approved' => (
            AppPalette.verified.withValues(alpha: 0.15),
            AppPalette.verified
          ),
        'failed' || 'declined' => (
            AppPalette.primary.withValues(alpha: 0.12),
            AppPalette.primary
          ),
        _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      };
}
