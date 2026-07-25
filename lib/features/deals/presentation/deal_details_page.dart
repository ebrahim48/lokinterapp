import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/notify.dart';
import '../../../core/utils/chat_gate.dart';
import '../../../core/utils/verify_gate.dart';
import '../../posts/presentation/widgets/mode_badge.dart';
import '../data/deal_model.dart';
import '../data/deals_repository.dart';
import 'deals_controller.dart';
import 'widgets/cancel_reason_sheet.dart';
import 'widgets/open_dispute_sheet.dart';
import 'widgets/status_badge.dart';

class DealDetailsPage extends StatefulWidget {
  final Deal deal;
  const DealDetailsPage({super.key, required this.deal});

  @override
  State<DealDetailsPage> createState() => _DealDetailsPageState();
}

class _DealDetailsPageState extends State<DealDetailsPage> {
  final _repo = DealsRepository();

  late Deal deal = widget.deal;
  bool _busy = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  // the list row is a trimmed shape — pull the full deal for this screen
  Future<void> _loadDetail() async {
    try {
      final full = await _repo.getById(widget.deal.id);
      if (!mounted) return;
      setState(() {
        deal = full;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      toastError(e);
    }
  }

  void _refreshList() {
    if (Get.isRegistered<DealsController>()) Get.find<DealsController>().load();
  }

  Future<void> _run(Future<void> Function() action, String done, {bool pop = true}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      _refreshList();
      toast(done);
      if (pop) {
        Get.back();
      } else {
        await _loadDetail();
      }
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // declining a pending deal is REJECTED; walking away later is CANCELED
  Future<void> _changeWithReason(String status, String done) async {
    final reason = await CancelReasonSheet.show(context);
    if (reason == null) return;
    await _run(
      () => _repo.changeStatus(deal.id, status, reason: reason.code),
      done,
    );
  }

  Future<void> _cancel() => _changeWithReason('CANCELED', 'Deal cancelled');
  Future<void> _reject() => _changeWithReason('REJECTED', 'Deal rejected');

  // accepting is entering the agreement, so identity verification is required
  Future<void> _acceptDeal() async {
    if (!await requireVerified()) return;
    await _run(() => _repo.changeStatus(deal.id, 'ACCEPTED'), 'Deal accepted', pop: false);
  }

  // Traveler guarantee: card HOLD for the item value. Same two-step the
  // website runs — create the intent, confirm the card in Stripe's sheet,
  // then tell the backend so it flips travelerGuaranteeHeld.
  Future<void> _secureGuarantee() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await _repo.createGuarantee(deal.id);
      final clientSecret = '${res['clientSecret'] ?? ''}';
      final intentId = '${res['paymentIntentId'] ?? ''}';
      if (clientSecret.isEmpty) {
        toast('Could not start the guarantee — try again');
        return;
      }
      final ok = await _presentStripeSheet(clientSecret);
      if (!ok) return;
      await _repo.confirmGuarantee(deal.id, intentId);
      _refreshList();
      toast('Guarantee secured — this is a hold, not a charge');
      await _loadDetail();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Sender escrow payment. Shows the fee breakdown the API returns before
  // opening the card sheet (item cost + profit + Lokinter fee = total).
  Future<void> _payNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await _repo.createPayment(deal.id);
      final clientSecret = '${res['clientSecret'] ?? ''}';
      final intentId = '${res['paymentIntentId'] ?? ''}';
      if (clientSecret.isEmpty) {
        toast('Could not start the payment — try again');
        return;
      }
      final breakdown = res['breakdown'] is Map
          ? Map<String, dynamic>.from(res['breakdown'])
          : null;
      if (breakdown != null) {
        final proceed = await _confirmBreakdown(breakdown);
        if (proceed != true) return;
      }
      final ok = await _presentStripeSheet(clientSecret);
      if (!ok) return;
      await _repo.confirmPayment(deal.id, intentId);
      _refreshList();
      toast('Payment secured in escrow');
      await _loadDetail();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmBreakdown(Map<String, dynamic> b) {
    String money(dynamic v) => '\$${double.tryParse('$v')?.toStringAsFixed(2) ?? '$v'}';
    final cs = Theme.of(context).colorScheme;
    Widget line(String label, dynamic v, {bool bold = false}) => Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13.sp,
                      color: bold ? cs.onSurface : cs.onSurfaceVariant,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
              Text(money(v),
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      color: cs.onSurface)),
            ],
          ),
        );
    return Get.dialog<bool>(
      AlertDialog(
        title: const Text('Payment breakdown'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (b['itemCost'] != null && double.tryParse('${b['itemCost']}') != 0)
              line('Item cost', b['itemCost']),
            if (b['profit'] != null) line('Traveler profit', b['profit']),
            if (b['lokinterFee'] != null) line('Lokinter fee', b['lokinterFee']),
            Divider(height: 16.h),
            line('Total', b['total'], bold: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Get.back(result: true), child: const Text('Continue')),
        ],
      ),
    );
  }

  /// Opens Stripe's native payment sheet for [clientSecret]. Returns true
  /// when the card was confirmed (hold placed), false on cancel/failure.
  Future<bool> _presentStripeSheet(String clientSecret) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Lokinter',
          style: ThemeMode.light,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        toast(e.error.localizedMessage ?? 'Card confirmation failed');
      }
      return false;
    } catch (e) {
      // anything else (native SDK not configured, plugin channel) would
      // otherwise escape and leave the button looking dead
      debugPrint('stripe sheet failed: $e');
      toast('Could not open the payment sheet — try again');
      return false;
    }
  }

  // eligibility first, then the pickup video, then flip to OUTGOING
  Future<void> _startOutgoing() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.checkOutgoingEligibility(deal.id);
    } on AppException catch (e) {
      toastError(e); // e.g. "The deal must be in ACCEPTED status."
      if (mounted) setState(() => _busy = false);
      return;
    }

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(type: FileType.video);
    } catch (_) {}
    final file = (picked?.files.isNotEmpty ?? false) ? picked!.files.first : null;
    if (file?.path == null) {
      toast('Pickup video is required to start the delivery');
      if (mounted) setState(() => _busy = false);
      return;
    }

    try {
      await _repo.uploadPickupVideo(deal.id, file!.path!, file.name);
      await _repo.changeStatus(deal.id, 'OUTGOING');
      _refreshList();
      toast('Pickup video uploaded — deal is now outgoing');
      await _loadDetail();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDispute() async {
    final filed = await OpenDisputeSheet.show(context, deal.id);
    if (filed == true) {
      _refreshList();
      await _loadDetail();
    }
  }

  Future<void> _showDisputeReport() async {
    try {
      final report = await _repo.disputeReport(deal.id);
      final text = report?['reason'] ??
          report?['description'] ??
          deal.dispute?['reason'] ??
          deal.cancelReasonLabel;
      Get.dialog(
        AlertDialog(
          title: const Text('Dispute report'),
          content: Text(text?.toString() ?? 'No report details available.'),
          actions: [TextButton(onPressed: () => Get.back(), child: const Text('Close'))],
        ),
      );
    } on AppException catch (e) {
      toastError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Deal #${deal.id}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDetail,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 28.h),
                children: [
                  _summary(context),
                  SizedBox(height: 16.h),
                  _counterpart(context),
                  SizedBox(height: 16.h),
                  _agreement(context),
                  // the sender shares this QR with the receiver throughout the
                  // live deal, not just once it's outgoing
                  if (deal.showsReceiverQr) ...[
                    SizedBox(height: 16.h),
                    _qrCard(context),
                  ],
                  if (deal.needsGuarantee) ...[
                    SizedBox(height: 16.h),
                    _guaranteeCard(context),
                  ],
                  if (deal.needsPayment) ...[
                    SizedBox(height: 16.h),
                    _paymentCard(context),
                  ],
                  // traveler can't proceed until the sender's escrow is funded
                  if (deal.travelerWaitingOnPayment) ...[
                    SizedBox(height: 16.h),
                    _waitingOnPayment(context),
                  ],
                  if (deal.status == DealStatus.outgoing) ...[
                    SizedBox(height: 16.h),
                    _ongoing(context),
                  ],
                  if (deal.status == DealStatus.disputes) ...[
                    SizedBox(height: 16.h),
                    _dispute(context),
                  ],
                  if (deal.status == DealStatus.cancelled &&
                      deal.cancelReasonLabel != null) ...[
                    SizedBox(height: 16.h),
                    _cancelledNote(context),
                  ],
                  SizedBox(height: 20.h),
                  ..._actions(context),
                ],
              ),
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
              ModeBadge(location: deal.location, place: deal.fromCountry),
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
              _stat(context, 'TRAVELER PROFIT', deal.profitLabel),
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
    final name = deal.counterpart.name;
    return _card(
      context,
      Row(
        children: [
          CircleAvatar(
            radius: 22.r,
            backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
            child: Text(
              name.isEmpty ? '?' : name[0],
              style: const TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Counterpart' : name,
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                SizedBox(height: 2.h),
                Text(deal.isTraveler ? 'Sender' : 'Traveler',
                    style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => openChat(deal.counterpart),
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
                  style: TextStyle(
                      fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
            ],
          ),
          SizedBox(height: 12.h),
          _depositRow(context),
          _row(context, 'Receiver name', deal.receiverName ?? '—'),
          _row(context, 'Receiver phone', deal.receiverPhone ?? '—'),
          _row(context, 'Traveler profit', deal.profitLabel),
          _row(context, 'Payment method', deal.paymentLabel),
          if (deal.attachUrl == null)
            _row(context, 'Attachment', 'Not provided')
          else
            _attachmentRow(context),
          if (deal.tripDate != null) _row(context, 'Trip date', shortDate(deal.tripDate!)),
          if (deal.arrivalDate != null)
            _row(context, 'Arrival date', shortDate(deal.arrivalDate!)),
        ],
      ),
    );
  }

  Widget _depositRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final required = deal.sdRequired;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Security deposit',
              style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: required ? const Color(0xFFFEF9C3) : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(required ? 'Required' : 'Not required',
                    style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: required ? const Color(0xFF854D0E) : cs.onSurfaceVariant)),
              ),
              if (required) ...[
                SizedBox(width: 8.w),
                Text(deal.depositLabel,
                    style: TextStyle(
                        fontSize: 13.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _attachmentRow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Attachment', style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
          TextButton.icon(
            onPressed: () => Get.dialog(
              Dialog(
                child: InteractiveViewer(
                  child: Image.network(
                    deal.attachUrl!,
                    errorBuilder: (_, __, ___) => Padding(
                      padding: EdgeInsets.all(24.w),
                      child: SelectableText(deal.attachUrl!,
                          style: TextStyle(fontSize: 12.sp)),
                    ),
                  ),
                ),
              ),
            ),
            icon: Icon(Icons.attachment, size: 15.sp, color: AppPalette.primary),
            label: Text('Open attachment',
                style: TextStyle(fontSize: 12.sp, color: AppPalette.primary)),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
          SizedBox(width: 12.w),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _guaranteeCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.credit_card, size: 17.sp, color: cs.onSurface),
              SizedBox(width: 8.w),
              Text('Guarantee required',
                  style: TextStyle(
                      fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Authorize ${deal.depositLabel} on your card as guarantee for the item value.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, height: 1.4),
          ),
          SizedBox(height: 4.h),
          Text(
            'This is a HOLD only — released (not charged) when the deal completes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.4),
          ),
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _secureGuarantee,
              icon: Icon(Icons.credit_card, size: 17.sp),
              label: const Text('Secure guarantee with card'),
            ),
          ),
        ],
      ),
    );
  }

  // sender side of the escrow flow — mirrors the web "Payment Required" panel
  Widget _paymentCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.credit_card, size: 17.sp, color: cs.onSurface),
              SizedBox(width: 8.w),
              Text('Payment required',
                  style: TextStyle(
                      fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Pay now to secure this deal. Funds are held until delivery is confirmed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, height: 1.4),
          ),
          SizedBox(height: 4.h),
          Text(
            'Your payment is auto-captured within 6 days, or when the traveler picks up the item.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.4),
          ),
          // the Pay now button lives with the other actions at the bottom
        ],
      ),
    );
  }

  // traveler is held back until the sender funds the escrow (live app parity)
  Widget _waitingOnPayment(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppPalette.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppPalette.primary, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cannot proceed',
                    style: TextStyle(
                        fontSize: 13.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                SizedBox(height: 4.h),
                Text(
                  'Waiting for the sender to complete payment before you can proceed.',
                  style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // in-flight: the parcel is with the traveler until delivery is confirmed
  Widget _ongoing(BuildContext context) {
    final (bg, fg) = DealStatus.outgoing.colors;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: fg, size: 18.sp),
              SizedBox(width: 8.w),
              Text('On the way',
                  style: TextStyle(color: fg, fontSize: 13.sp, fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            deal.isTraveler
                ? 'You have the parcel. Mark it delivered once the receiver has it.'
                : 'The traveler has picked up the parcel and is on the way.',
            style: TextStyle(color: fg, fontSize: 12.sp, height: 1.4),
          ),
          if (deal.arrivalDate != null) ...[
            SizedBox(height: 6.h),
            Text('Expected arrival ${shortDate(deal.arrivalDate!)}',
                style: TextStyle(color: fg, fontSize: 11.sp)),
          ],
        ],
      ),
    );
  }

  // The receiver scans this to confirm delivery on the website's public
  // deal page (deal-details/{refId}) — no app or account needed.
  Widget _qrCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final link = deal.confirmationLink;
    return _card(
      context,
      Column(
        children: [
          Text('Receiver confirmation',
              style: TextStyle(
                  fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
          SizedBox(height: 6.h),
          Text(
            'Have the receiver scan this code when the parcel arrives — '
            'it confirms the delivery and releases the deal.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, height: 1.4),
          ),
          SizedBox(height: 14.h),
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: cs.outline),
            ),
            child: QrImageView(
              data: link,
              size: 180.r,
              backgroundColor: Colors.white,
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
          Text(
            deal.dispute?['reason']?.toString() ??
                'The team is reviewing this delivery.',
            style: TextStyle(color: fg, fontSize: 12.sp, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _cancelledNote(BuildContext context) {
    final (bg, fg) = DealStatus.cancelled.colors;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14.r)),
      child: Row(
        children: [
          Icon(Icons.cancel_outlined, color: fg, size: 17.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text('Cancelled — ${deal.cancelReasonLabel}',
                style: TextStyle(color: fg, fontSize: 12.sp)),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    switch (deal.status) {
      case DealStatus.pending:
        return [
          // the side that proposed the agreement can only withdraw it
          if (!deal.isProposer) ...[
            ElevatedButton(
              onPressed: _busy ? null : _acceptDeal,
              child: const Text('Accept deal'),
            ),
            SizedBox(height: 12.h),
          ],
          OutlinedButton(
            onPressed: _busy ? null : _reject,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.primary,
              side: const BorderSide(color: AppPalette.primary),
            ),
            child: const Text('Reject deal'),
          ),
        ];
      case DealStatus.accepted:
        return [
          // sender funds the escrow; traveler films the handover
          if (deal.needsPayment) ...[
            ElevatedButton.icon(
              onPressed: _busy ? null : _payNow,
              icon: Icon(Icons.credit_card, size: 17.sp),
              label: const Text('Pay now'),
            ),
            SizedBox(height: 12.h),
          ],
          // the traveler can only start once the sender has paid and their own
          // guarantee (if required) is secured
          if (deal.isTraveler) ...[
            ElevatedButton.icon(
              onPressed: (_busy || !deal.travelerCanStart) ? null : _startOutgoing,
              icon: Icon(Icons.upload_outlined, size: 17.sp),
              label: const Text('Upload Purchase Video & Check As Ongoing'),
            ),
            SizedBox(height: 12.h),
          ],
          OutlinedButton(
            onPressed: _busy ? null : _cancel,
            child: const Text('Cancel deal'),
          ),
        ];
      case DealStatus.outgoing:
        // once the parcel is moving, walking away is a dispute, not a
        // cancel (website: cancel is only offered while ACCEPTED)
        return [
          if (!deal.isTraveler) ...[
            ElevatedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() => _repo.markCompleted(deal.refId), 'Marked as delivered'),
              child: const Text('Mark as delivered'),
            ),
            SizedBox(height: 12.h),
          ],
          OutlinedButton.icon(
            onPressed: _busy ? null : _openDispute,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.primary,
              side: const BorderSide(color: AppPalette.primary),
            ),
            icon: Icon(Icons.gpp_maybe_outlined, size: 17.sp),
            label: const Text('Open a dispute'),
          ),
        ];
      case DealStatus.completed:
        // only the sender reviews the deal (website: isDealReviewable)
        return [
          if (!deal.isTraveler) ...[
            ElevatedButton(
              onPressed: () => _openRateSheet(context),
              child: const Text('Rate this deal'),
            ),
            SizedBox(height: 12.h),
          ],
          OutlinedButton.icon(
            onPressed: _busy ? null : _openDispute,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.primary,
              side: const BorderSide(color: AppPalette.primary),
            ),
            icon: Icon(Icons.gpp_maybe_outlined, size: 17.sp),
            label: const Text('Open a dispute'),
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
