import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/notify.dart';
import '../../chat/presentation/chat_conversation_page.dart';
import '../../posts/presentation/widgets/mode_badge.dart';
import '../data/deal_model.dart';
import '../data/deals_repository.dart';
import 'deals_controller.dart';
import 'widgets/status_badge.dart';

class DealDetailsPage extends StatefulWidget {
  final Deal deal;
  const DealDetailsPage({super.key, required this.deal});

  @override
  State<DealDetailsPage> createState() => _DealDetailsPageState();
}

class _DealDetailsPageState extends State<DealDetailsPage> {
  final _repo = DealsRepository();
  bool _busy = false;

  Deal get deal => widget.deal;

  // runs an action, refreshes the list behind us and pops back to it
  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (Get.isRegistered<DealsController>()) Get.find<DealsController>().load();
      toast(doneMessage);
      Get.back();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withReason(String title, String status) async {
    final reason = TextEditingController();
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: TextField(
          controller: reason,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Tell the other side why'),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Back')),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(title, style: const TextStyle(color: AppPalette.primary)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(
        () => _repo.changeStatus(deal.id, status, reason: reason.text.trim()),
        'Deal updated',
      );
    }
    reason.dispose();
  }

  Future<void> _showDisputeReport() async {
    try {
      final report = await _repo.disputeReport(deal.id);
      final text = report?['reason'] ?? report?['description'] ?? deal.disputeReason;
      Get.dialog(
        AlertDialog(
          title: const Text('Dispute report'),
          content: Text(text?.toString() ?? 'No report details available.'),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Close')),
          ],
        ),
      );
    } on AppException catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Deal #${deal.refId}')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 28.h),
        children: [
          _summary(context),
          SizedBox(height: 16.h),
          _counterpart(context),
          SizedBox(height: 16.h),
          if (deal.status != DealStatus.pending) ...[
            _agreement(context),
            SizedBox(height: 16.h),
          ],
          if (deal.status == DealStatus.disputes)
            _dispute(context)
          else if (deal.status == DealStatus.completed)
            _ratePrompt(context)
          else
            _qr(context),
          SizedBox(height: 20.h),
          ..._actions(context),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outline),
      ),
      child: child,
    );
  }

  Widget _summary(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      context,
      Column(
        children: [
          Row(
            children: [
              Expanded(child: _stat(context, 'FROM', deal.fromCountry)),
              ModeBadge(location: deal.location, place: deal.fromCountry, iso: deal.fromIso),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _stat(context, 'TO', deal.toCountry, end: true),
                ),
              ),
            ],
          ),
          Divider(height: 24.h, color: cs.outline),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat(context, 'DATE', shortDate(deal.date)),
              _stat(context, 'WEIGHT', kg(deal.weight)),
              _stat(context, 'PROFIT', deal.profit),
            ],
          ),
          SizedBox(height: 12.h),
          Align(alignment: Alignment.centerLeft, child: StatusBadge(status: deal.status)),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, {bool end = false}) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 9.sp, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
        SizedBox(height: 3.h),
        Text(value,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
      ],
    );
  }

  Widget _counterpart(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      context,
      Row(
        children: [
          CircleAvatar(
            radius: 22.r,
            backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
            child: Text(
              deal.counterpart.name[0],
              style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(deal.counterpart.name,
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                    if (deal.counterpart.verified) ...[
                      SizedBox(width: 4.w),
                      Icon(Icons.verified, size: 15.sp, color: AppPalette.verified),
                    ],
                  ],
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Icon(Icons.star, size: 13.sp, color: Colors.amber),
                    SizedBox(width: 3.w),
                    Text(deal.counterpart.rating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                Get.to(() => ChatConversationPage(user: deal.counterpart)),
            style: OutlinedButton.styleFrom(minimumSize: Size(0, 40.h)),
            icon: Icon(Icons.chat_bubble_outline, size: 16.sp),
            label: const Text('Chat'),
          ),
        ],
      ),
    );
  }

  Widget _agreement(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = <(String, String)>[
      ('Receiver', deal.counterpart.name),
      ('Agreed amount', deal.profit),
      ('Weight', deal.agreedWeight),
      ('Trip date', shortDate(deal.date)),
      ('Payment method', deal.paymentMethod),
    ];
    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined, size: 18.sp, color: AppPalette.primary),
              SizedBox(width: 8.w),
              Text('Agreement details',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
            ],
          ),
          SizedBox(height: 4.h),
          Text('As confirmed in the chat between both parties.',
              style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
          SizedBox(height: 12.h),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 18.h, color: cs.outline),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(rows[i].$1, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
                Flexible(
                  child: Text(
                    rows[i].$2,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: cs.onSurface),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _qr(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      context,
      Column(
        children: [
          Text('Agreement code',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
          SizedBox(height: 4.h),
          Text(
            'Show this code at pickup and delivery to confirm the handover.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.qr_code_2, size: 140.sp, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _ratePrompt(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      context,
      Row(
        children: [
          Icon(Icons.check_circle, color: AppPalette.verified, size: 22.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Delivery completed. How was it?',
              style: TextStyle(fontSize: 13.sp, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dispute(BuildContext context) {
    final (bg, fg) = DealStatus.disputes.colors;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gpp_maybe_outlined, color: fg, size: 18.sp),
              SizedBox(width: 8.w),
              Text('Dispute open',
                  style: TextStyle(color: fg, fontSize: 13.sp, fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: 8.h),
          Text(deal.disputeReason ?? '',
              style: TextStyle(color: fg, fontSize: 12.sp, height: 1.4)),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    switch (deal.status) {
      case DealStatus.pending:
        return [
          ElevatedButton(
            onPressed: _busy
                ? null
                : () => _run(
                      () => _repo.changeStatus(deal.id, 'ACCEPTED'),
                      'Agreement accepted',
                    ),
            child: const Text('Accept agreement'),
          ),
          SizedBox(height: 12.h),
          OutlinedButton(
            onPressed: _busy ? null : () => _withReason('Decline', 'REJECTED'),
            child: const Text('Decline'),
          ),
        ];
      case DealStatus.accepted:
      case DealStatus.outgoing:
        return [
          ElevatedButton(
            onPressed: _busy
                ? null
                : () => _run(
                      () => _repo.markCompleted(deal.refId),
                      'Marked as delivered',
                    ),
            child: const Text('Mark as delivered'),
          ),
          SizedBox(height: 12.h),
          OutlinedButton(
            onPressed: _busy ? null : () => _withReason('Cancel agreement', 'CANCELED'),
            child: const Text('Cancel agreement'),
          ),
        ];
      case DealStatus.completed:
        return [
          ElevatedButton(
            onPressed: () => _openRateSheet(context),
            child: const Text('Rate this deal'),
          ),
        ];
      case DealStatus.disputes:
        return [
          ElevatedButton(
            onPressed: _showDisputeReport,
            child: const Text('View dispute report'),
          ),
        ];
      case DealStatus.cancelled:
        return [
          OutlinedButton(onPressed: () => Get.back(), child: const Text('Back to deals')),
        ];
    }
  }

  void _openRateSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (_) => _RateSheet(deal: deal),
    );
  }
}

class _RateSheet extends StatefulWidget {
  final Deal deal;
  const _RateSheet({required this.deal});

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  final _repo = DealsRepository();
  final _comment = TextEditingController();
  int _stars = 5;
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await _repo.rate(widget.deal.id, _stars, _comment.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      toast('Thanks for the review!');
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rate this deal', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 14.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return IconButton(
                  onPressed: () => setState(() => _stars = i + 1),
                  icon: Icon(
                    i < _stars ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 36.sp,
                  ),
                );
              }),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _comment,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Leave a comment (optional)'),
            ),
            SizedBox(height: 18.h),
            ElevatedButton(
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit review'),
            ),
          ],
        ),
      ),
    );
  }
}
