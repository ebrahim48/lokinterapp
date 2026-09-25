import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/notify.dart';
import '../../../core/widgets/lok_segmented.dart';
import '../data/wallet_repository.dart';
import 'package:get/get.dart';

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
    } catch (_) {
      // a malformed row must not leave the spinner up forever
      if (!mounted) return;
      setState(() => _loading = false);
      toast('something_went_wrong_try_again'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('wallet_activity'.tr)),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 4.h),
            child: LokSegmented(
              labels: ['transactions'.tr, 'withdrawals'.tr],
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
          Text('no_transactions_yet'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
        ],
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline),
      itemBuilder: (_, i) => _txTile(cs, _transactions[i]),
    );
  }

  Widget _txTile(ColorScheme cs, WalletTransaction t) {
    final credit = t.isCredit;

    // Use displayDescription (human-readable) over raw description.
    // Fall back gracefully: displayDescription → description → type label.
    // Sanitise every candidate — backend sometimes echoes encrypted refs here.
    String clean(String s) => _looksEncrypted(s) ? '' : s;
    final label = clean(t.displayDescription).isNotEmpty
        ? clean(t.displayDescription)
        : clean(t.description).isNotEmpty
            ? clean(t.description)
            : _typeLabel(t.type);

    // Use dealDisplayId (#DL-123), else the numeric id. The raw dealRef is a
    // technical code and is never shown — the backend sometimes echoes it
    // into dealDisplayId too, so sanitise that as well.
    final rawDisplayId = t.dealDisplayId;
    final dealLabel = rawDisplayId.isNotEmpty && !_looksEncrypted(rawDisplayId)
        ? rawDisplayId
        : t.dealId != 0
            ? 'Deal #${t.dealId}'
            : '';
    final status = t.statusLabel.isNotEmpty
        ? t.statusLabel
        : t.status.isNotEmpty
            ? _statusLabel(t.status)
            : t.reason;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Direction icon
          CircleAvatar(
            radius: 18.r,
            backgroundColor:
                (credit ? AppPalette.verified : cs.onSurfaceVariant)
                    .withValues(alpha: 0.12),
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
                // Human-readable description — no raw encrypted strings
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.sp, color: cs.onSurface),
                ),
                SizedBox(height: 4.h),
                // Type chip + status badge in a row
                Wrap(
                  spacing: 6.w,
                  runSpacing: 4.h,
                  children: [
                    _typeChip(cs, t.type, credit),
                    if (status.isNotEmpty) _statusBadge(cs, status),
                  ],
                ),
                SizedBox(height: 4.h),
                // Deal ID (human-readable) and date — NO raw refs
                Text(
                  [
                    if (dealLabel.isNotEmpty) dealLabel,
                    if (t.createdAt != null) shortDateTime(t.createdAt!),
                  ].join('  •  '),
                  style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Amount + running balance
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
              Text(
                '${'balance'.tr}: \$${t.balanceAfter.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Compact pill showing the transaction type (e.g. "Credit", "Debit").
  Widget _typeChip(ColorScheme cs, String type, bool credit) {
    final (bg, fg) = switch (type) {
      'credit' => (AppPalette.verified.withValues(alpha: 0.12), AppPalette.verified),
      'refund' => (AppPalette.verified.withValues(alpha: 0.12), AppPalette.verified),
      'release' => (AppPalette.verified.withValues(alpha: 0.12), AppPalette.verified),
      'external_credit' => (AppPalette.verified.withValues(alpha: 0.12), AppPalette.verified),
      'debit' => (cs.errorContainer.withValues(alpha: 0.6), cs.error),
      'reserve' => (Colors.orange.withValues(alpha: 0.12), Colors.orange.shade700),
      'external_debit' => (cs.errorContainer.withValues(alpha: 0.6), cs.error),
      _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        _typeLabel(type),
        style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  /// Status badge (e.g. "Pending Release", "On Hold") — shown when present.
  Widget _statusBadge(ColorScheme cs, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppPalette.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 10.sp, fontWeight: FontWeight.w600, color: AppPalette.primary),
      ),
    );
  }

  /// Returns true when a string looks like a raw encrypted reference
  /// (e.g. long hex/base64, Laravel-encrypted `eyJ…` token) that should
  /// NOT be shown to the user.
  bool _looksEncrypted(String s) {
    if (s.length < 12) return false;
    // Laravel AES-encrypted payloads always start with eyJ (base64 of `{"iv":`)
    if (s.startsWith('eyJ')) return true;
    // All-hex strings of length ≥ 12 are assumed to be internal refs
    if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(s)) return true;
    // base64-like patterns (no whitespace, only base64 alphabet, long enough)
    if (RegExp(r'^[A-Za-z0-9+/=]{20,}$').hasMatch(s)) return true;
    return false;
  }

  String _typeLabel(String type) => switch (type) {
        'credit' => 'earning_credited'.tr,
        'debit' => 'withdrawal'.tr,
        'refund' => 'refund'.tr,
        'reserve' => 'amount_reserved'.tr,
        'release' => 'reserve_released'.tr,
        'external_credit' => 'top_up'.tr,
        'external_debit' => 'external_payout'.tr,
        _ => type,
      };

  Widget _requestList(ColorScheme cs) {
    if (_requests.isEmpty) {
      return ListView(
        padding: EdgeInsets.all(24.w),
        children: [
          Text('no_withdrawal_requests_yet'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
        ],
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      itemCount: _requests.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: cs.outline),
      itemBuilder: (_, i) => _requestTile(cs, _requests[i]),
    );
  }

  Widget _requestTile(ColorScheme cs, PayoutRequestRow r) {
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
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface),
                ),
                SizedBox(height: 2.h),
                Text(
                  [
                    if (r.feeAmount > 0)
                      '${'fee'.tr}: \$${r.feeAmount.toStringAsFixed(2)}',
                    if (r.netAmount > 0)
                      '${'net_amount'.tr}: \$${r.netAmount.toStringAsFixed(2)}',
                    if (r.requestedAt != null) shortDate(r.requestedAt!),
                  ].join(' · '),
                  style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(20.r)),
            child: Text(
              _statusLabel(r.status),
              style: TextStyle(
                  fontSize: 10.sp, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ],
      ),
    );
  }

  // Pending → Processing → Paid / Rejected / Failed
  String _statusLabel(String s) => switch (s.toLowerCase()) {
        'pending' || 'pending_admin_review' => 'pending'.tr,
        'processing' || 'approved' => 'processing'.tr,
        'fulfilled' || 'paid' || 'completed' => 'paid'.tr,
        'failed' => 'failed'.tr,
        'declined' || 'rejected' => 'rejected'.tr,
        'cancelled' || 'canceled' => 'cancelled'.tr,
        _ => s,
      };

  (Color, Color) _statusColors(String s, ColorScheme cs) => switch (s.toLowerCase()) {
        'fulfilled' || 'paid' || 'completed' => (
            AppPalette.verified.withValues(alpha: 0.15),
            AppPalette.verified
          ),
        'failed' || 'declined' || 'rejected' => (
            AppPalette.primary.withValues(alpha: 0.12),
            AppPalette.primary
          ),
        _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      };
}
