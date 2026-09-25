import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/notify.dart';
import '../../../core/utils/phone_gate.dart';
import '../../../core/utils/stripe_sheet.dart';
import '../../../core/utils/chat_gate.dart';
import '../../../core/utils/verify_gate.dart';
import '../../posts/presentation/widgets/mode_badge.dart';
import '../../posts/presentation/widgets/transporter_chip.dart';
import '../data/deal_model.dart';
import '../data/deals_repository.dart';
import 'deals_controller.dart';
import 'scan_delivery_page.dart';
import 'widgets/cancel_reason_sheet.dart';
import 'widgets/open_dispute_sheet.dart';
import 'widgets/status_badge.dart';
import '../../../core/widgets/image_viewer.dart';

class DealDetailsPage extends StatefulWidget {
  final Deal deal;
  const DealDetailsPage({super.key, required this.deal});

  @override
  State<DealDetailsPage> createState() => _DealDetailsPageState();
}

class _DealDetailsPageState extends State<DealDetailsPage> {
  final _repo = DealsRepository();

  late Deal deal = widget.deal;
  /// The submitted dispute, fetched when the deal payload doesn't carry it.
  Map<String, dynamic>? _disputeReport;
  bool _busy = false;
  bool _loading = true;
  StreamSubscription<Map<String, dynamic>>? _dealSub;
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _subscribeDealRealtime();
  }

  void _subscribeDealRealtime() {
    if (Get.isRegistered<SocketService>()) {
      final socket = Get.find<SocketService>();
      socket.subscribeDeal(widget.deal.id);
      _dealSub = socket.dealEvents.listen((payload) {
        final id = payload['dealId'];
        if (id != null && id != widget.deal.id) return;
        // reload deal from backend to get fresh state (canMarkCompleted, status, etc.)
        _loadDetail();
      });
      // Start a polling fallback — if no socket event arrives within 10 seconds
      // the timer keeps the deal state in sync regardless of socket health.
      _startPolling();
    } else {
      // No socket service at all — rely entirely on polling
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (mounted && !_busy) _loadDetail(quiet: true);
    });
  }

  // the list row is a trimmed shape — pull the full deal for this screen
  Future<void> _loadDetail({bool quiet = false}) async {
    try {
      final full = await _repo.getById(widget.deal.id);
      if (!mounted) return;
      setState(() {
        // getById doesn't echo the item name/notes, so keep what the list row
        // already gave us instead of blanking them out
        deal = full.withItemDetailsFrom(widget.deal);
        _loading = false;
      });
      if (full.hasDisputeRecord &&
          full.disputeDetails == null &&
          _disputeReport == null) {
        _loadDisputeReport();
      }
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!quiet) toastError(e);
    }
  }

  // quiet: the card falls back to whatever the deal payload had
  Future<void> _loadDisputeReport() async {
    try {
      final report = await _repo.disputeReport(deal.id);
      if (mounted && report != null) setState(() => _disputeReport = report);
    } catch (_) {}
  }

  void _refreshList() {
    if (Get.isRegistered<DealsController>()) Get.find<DealsController>().load();
  }

  @override
  void dispose() {
    _dealSub?.cancel();
    _pollTimer?.cancel();
    if (Get.isRegistered<SocketService>()) {
      Get.find<SocketService>().leaveDeal(widget.deal.id);
    }
    super.dispose();
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
      // a 403 requiresKyc routes to verification instead of a dead-end toast
      if (!maybeKycPrompt(e)) toastError(e);
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

  // accepting is entering the agreement: verified number, then documents
  Future<void> _acceptDeal() async {
    if (!await requirePhoneVerified(action: 'accept a deal')) return;
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
        toast('could_not_start_the_guarantee_try_again'.tr);
        return;
      }
      final ok = await presentStripeSheet(clientSecret);
      if (!ok) return;
      await _repo.confirmGuarantee(deal.id, intentId);
      _refreshList();
      toast('guarantee_secured_this_is_a_hold_not_a_charge'.tr);
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
        toast('could_not_start_the_payment_try_again'.tr);
        return;
      }
      final breakdown = res['breakdown'] is Map
          ? Map<String, dynamic>.from(res['breakdown'])
          : null;
      if (breakdown != null) {
        final proceed = await _confirmBreakdown(breakdown);
        if (proceed != true) return;
      }
      final ok = await presentStripeSheet(clientSecret);
      if (!ok) return;
      await _repo.confirmPayment(deal.id, intentId);
      _refreshList();
      toast('payment_secured_in_escrow'.tr);
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
        title: Text('payment_breakdown'.tr),
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
          TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
          ElevatedButton(
              onPressed: () => Get.back(result: true), child: Text('continue'.tr)),
        ],
      ),
    );
  }

  // eligibility first, then the pickup video (record or choose a file),
  // uploaded with a live progress bar, then flip to OUTGOING.
  // IMPORTANT: do NOT show "collected" until changeStatus OUTGOING succeeds.
  Future<void> _startOutgoing() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.checkOutgoingEligibility(deal.id);
    } on AppException catch (e) {
      toastError(e);
      if (mounted) setState(() => _busy = false);
      return;
    }

    final pick = await _pickVideo();
    if (pick == null) {
      toast('record_the_pickup_video_to_start_the_delivery'.tr);
      if (mounted) setState(() => _busy = false);
      return;
    }

    final progress = ValueNotifier<double>(0);
    _showUploadProgress(progress);

    // Step 1: upload — extended 600s timeout to handle large video files on
    // slow connections (30s raw camera video can be 50–200 MB).
    // IMPORTANT: do NOT advance to OUTGOING on any upload failure.
    try {
      await _repo.uploadPickupVideo(
        deal.id,
        pick.$1,
        pick.$2,
        onProgress: (sent, total) {
          if (total > 0) progress.value = sent / total;
        },
        timeout: const Duration(seconds: 600),
      );
    } on AppException catch (e) {
      // Upload failed — do NOT advance to OUTGOING, do NOT show pickup message
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      progress.dispose();
      if (mounted) setState(() => _busy = false);
      toastError(e);
      return; // retryable — user can tap again
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      progress.dispose();
      if (mounted) setState(() => _busy = false);
      toast('video_upload_failed_please_try_again'.tr);
      return;
    }

    // Step 2: only after upload succeeds, change status to OUTGOING
    try {
      await _repo.changeStatus(deal.id, 'OUTGOING');
    } on AppException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      progress.dispose();
      if (mounted) setState(() => _busy = false);
      toastError(e);
      return;
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
    if (mounted) setState(() => _busy = false);

    // "Item collected" is shown ONLY here — both upload AND changeStatus succeeded
    _refreshList();
    toast('pickup_video_uploaded_deal_is_now_outgoing'.tr);
    await _loadDetail();
  }

  // Live mode records the handover on the spot — the camera opens directly and
  // caps at 30s. Picking a ready-made file is deliberately not offered, so the
  // video can't be anything but the actual pickup.
  Future<(String path, String name)?> _pickVideo() async {
    // the manifest declares CAMERA for the QR scanner, which makes image_picker
    // require the runtime grant too — ask before opening the recorder
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      toast('camera_permission_is_needed_to_record'.tr);
      return null;
    }
    try {
      final x = await ImagePicker().pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
        preferredCameraDevice: CameraDevice.rear,
      );
      if (x == null) return null;

      // Check file size before attempting the upload.
      // Raw camera video can be 50–200 MB for 30 seconds; the server limit is
      // 200 MB. Warn the user early so the progress dialog never appears for a
      // video that will be rejected server-side.
      final bytes = await File(x.path).length();
      const maxBytes = 200 * 1024 * 1024; // 200 MB
      if (bytes > maxBytes) {
        toast('video_too_large_keep_it_under_30_seconds'.tr);
        return null;
      }

      return (x.path, x.name);
    } on PlatformException catch (e) {
      // no camera (emulator without one) or permission refused
      toast(e.message ?? 'Could not open the camera');
      return null;
    }
  }

  void _showUploadProgress(ValueNotifier<double> progress) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_upload_outlined,
                    color: AppPalette.primary, size: 20.sp),
                SizedBox(width: 10.w),
                Text('uploading_video'.tr,
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
              ],
            ),
            SizedBox(height: 18.h),
            ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (_, v, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: LinearProgressIndicator(
                      value: v == 0 ? null : v, // indeterminate until first bytes
                      minHeight: 8.h,
                      backgroundColor: AppPalette.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    v == 0 ? 'Preparing…' : '${(v * 100).round()}%',
                    style: TextStyle(fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handover: scan the receiver's QR, record the delivery, close the deal.
  // The website reaches the same endpoints from its public deal-details page;
  // doing it here keeps the traveler in the app.
  Future<void> _scanAndComplete() async {
    final ref = await ScanDeliveryPage.open(context);
    if (ref == null || !mounted) return;

    // guard against scanning some other deal's code
    if (ref != deal.refId) {
      try {
        final scanned = await _repo.getByReferenceId(ref);
        if (scanned.id != deal.id) {
          toast('that_qr_belongs_to_another_deal'.tr);
          return;
        }
      } on AppException catch (e) {
        toastError(e);
        return;
      }
    }
    if (!mounted) return;

    final pick = await _pickVideo();
    if (pick == null) {
      toast('record_the_delivery_video_to_complete'.tr);
      return;
    }
    // a dispute may have been filed while the camera was open
    if (deal.disputeActive) {
      toast('deal_under_dispute_cannot_complete'.tr);
      return;
    }

    setState(() => _busy = true);
    final progress = ValueNotifier<double>(0);
    _showUploadProgress(progress);
    var done = false;
    try {
      await _repo.uploadDeliveryVideo(
        ref,
        pick.$1,
        pick.$2,
        onProgress: (sent, total) {
          if (total > 0) progress.value = sent / total;
        },
      );
      await _repo.markCompleted(ref);
      done = true;
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      progress.dispose();
      if (mounted) setState(() => _busy = false);
    }

    if (done) {
      _refreshList();
      toast('delivery_recorded_deal_completed'.tr);
      await _loadDetail();
    }
  }

  Future<void> _openDispute() async {
    final filed = await OpenDisputeSheet.show(context, deal.id);
    if (filed == true) {
      _disputeReport = null; // pull the report that was just submitted
      _refreshList();
      await _loadDetail();
    }
  }

  /// The full dispute record: what was raised, what the admin decided, and any
  /// notes they left. The resolution is the part people actually need — a bare
  /// reason tells them nothing about the outcome.
  Future<void> _showDisputeReport() async {
    Map<String, dynamic>? report;
    try {
      report = await _repo.disputeReport(deal.id);
    } on AppException catch (e) {
      toastError(e);
      return;
    }

    final d = report ?? _disputeReport ?? deal.disputeInfo ?? const <String, dynamic>{};
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = d[k];
        if (v != null && '$v'.trim().isNotEmpty) return '$v';
      }
      return null;
    }

    final reason = pick(['reason_label', 'reasonLabel', 'reason']);
    final description = pick(['description']);
    final status = pick(['status_label', 'statusLabel', 'status']);
    final decision = pick(['decision_label', 'decisionLabel', 'adminDecision']);
    final notes = pick(['resolution_notes', 'resolutionNotes']);
    final resolvedAt = pick(['resolved_at', 'resolvedAt']);

    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;

    Widget line(String label, String value, {bool emphasise = false}) => Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10.5.sp,
                      letterSpacing: 0.4,
                      color: cs.onSurfaceVariant)),
              SizedBox(height: 2.h),
              Text(value,
                  style: TextStyle(
                      fontSize: 13.sp,
                      height: 1.35,
                      fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
                      color: emphasise ? AppPalette.primary : cs.onSurface)),
            ],
          ),
        );

    Get.dialog(
      AlertDialog(
        title: Text('dispute_report'.tr),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reason != null) line('reason'.tr, reason),
              if (description != null) line('description'.tr, description),
              if (status != null) line('status'.tr, status),
              // what the admin actually did, and why
              if (decision != null)
                line('admin_decision'.tr, decision, emphasise: true),
              if (notes != null) line('admin_notes'.tr, notes),
              if (resolvedAt != null) line('resolved'.tr, resolvedAt),
              if (reason == null &&
                  decision == null &&
                  notes == null &&
                  description == null)
                Text('no_report_details_available'.tr,
                    style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('close'.tr))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('deal_number'.trParams({'id': '${deal.id}'}))),
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
                  // the submitted report stays visible for the whole dispute,
                  // even if the server kept the deal's own status
                  if (deal.hasDisputeRecord) ...[
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
                Row(
                  children: [
                    Flexible(
                      child: Text(name.isEmpty ? 'Counterpart' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                    ),
                    if (deal.counterpart.isTransporter) ...[
                      SizedBox(width: 6.w),
                      TransporterChip(recommended: false),
                    ],
                  ],
                ),
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
            label: Text('chat'.tr),
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
              Text('agreement_details'.tr,
                  style: TextStyle(
                      fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
            ],
          ),
          SizedBox(height: 12.h),
          _depositRow(context),
          _row(context, 'Receiver name', deal.receiverName ?? '—'),
          _row(context, 'Receiver phone', deal.receiverPhone ?? '—'),
          _row(context, 'Traveler profit', deal.profitLabel),
          // what the item is worth — the security-deposit basis on a SEND deal
          if (deal.itemEstimatedCost != null && deal.itemEstimatedCost! > 0)
            _row(
              context,
              deal.wantTo == 'BUY_AND_DELIVER'
                  ? 'item_value'.tr
                  : 'security_deposit_amount'.tr,
              deal.depositLabel,
            ),
          _row(context, 'Payment method', deal.paymentLabel),
          // item details the sender filled in — the traveler needs these
          if ((deal.itemName ?? '').isNotEmpty)
            _row(context, 'Item name', deal.itemName!),
          if (deal.wantToLabel != null)
            _row(context, 'i_want_to'.tr, deal.wantToLabel!),
          if ((deal.itemLink ?? '').isNotEmpty) _linkRow(context, deal.itemLink!),
          if ((deal.notes ?? '').isNotEmpty)
            _row(context, 'Notes', deal.notes!),
          if (deal.attachUrls.isNotEmpty)
            _attachmentGallery(context)
          else if (deal.attachUrl == null)
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

  // every attached picture, not just the first — tap any to zoom
  Widget _attachmentGallery(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('attachments_count'.trParams({'n': '${deal.attachUrls.length}'}),
              style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
          SizedBox(height: 8.h),
          SizedBox(
            height: 84.r,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: deal.attachUrls.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => ImageViewerPage.open(context, deal.attachUrls[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: Image.network(
                    deal.attachUrls[i],
                    width: 84.r,
                    height: 84.r,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 84.r,
                      height: 84.r,
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.broken_image_outlined,
                          size: 22.sp, color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ),
          ),
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
          Text('security_deposit'.tr,
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
          Text('attachment'.tr, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
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
            label: Text('open_attachment'.tr,
                style: TextStyle(fontSize: 12.sp, color: AppPalette.primary)),
          ),
        ],
      ),
    );
  }

  // the product link opens in the browser instead of sitting there as text
  Widget _linkRow(BuildContext context, String url) {
    final cs = Theme.of(context).colorScheme;
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('item_link'.tr,
              style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
          SizedBox(width: 12.w),
          Expanded(
            child: GestureDetector(
              onTap: uri == null
                  ? null
                  : () => launchUrl(uri, mode: LaunchMode.externalApplication),
              child: Text(
                url,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppPalette.primary,
                ),
              ),
            ),
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
              Text('guarantee_required'.tr,
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
            'this_is_a_hold_only_released_not_charged_when_th'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.4),
          ),
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _secureGuarantee,
              icon: Icon(Icons.credit_card, size: 17.sp),
              label: Text('secure_guarantee_with_card'.tr),
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
              Text('payment_required'.tr,
                  style: TextStyle(
                      fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'pay_now_to_secure_this_deal_funds_are_held_until'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, height: 1.4),
          ),
          SizedBox(height: 4.h),
          Text(
            'your_payment_is_auto_captured_within_6_days_or_w'.tr,
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
                Text('cannot_proceed'.tr,
                    style: TextStyle(
                        fontSize: 13.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                SizedBox(height: 4.h),
                Text(
                  'waiting_for_the_sender_to_complete_payment_befor'.tr,
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
              Text('on_the_way'.tr,
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
            Text('expected_arrival_on'.trParams({'date': shortDate(deal.arrivalDate!)}),
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
          Text('receiver_confirmation'.tr,
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
    // prefer the rich disputeDetails block over the legacy dispute map
    final details = deal.disputeDetails ?? _disputeReport ?? deal.dispute;
    final reason = (details?['reasonLabel'] ??
            details?['reason_label'] ??
            details?['reason'])
        ?.toString();
    final description = details?['description']?.toString();
    final statusLabel = details?['statusLabel']?.toString() ?? details?['status']?.toString();
    final attachments = details?['attachments'];
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
              Text(deal.disputeActive ? 'dispute_open'.tr : 'dispute_report'.tr,
                  style: TextStyle(color: fg, fontSize: 13.sp, fontWeight: FontWeight.w700)),
              if (statusLabel != null && statusLabel.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 9.sp, fontWeight: FontWeight.w700, color: fg)),
                ),
              ],
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(reason,
                style: TextStyle(
                    color: fg, fontSize: 13.sp, fontWeight: FontWeight.w600)),
          ],
          if (description != null && description.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(description,
                style: TextStyle(color: fg, fontSize: 12.sp, height: 1.4)),
          ],
          if (attachments is List && attachments.isNotEmpty) ...[
            SizedBox(height: 10.h),
            SizedBox(
              height: 72.r,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: attachments.length,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (ctx, i) {
                  final url = attachments[i] is Map
                      ? (attachments[i]['url'] ?? attachments[i]['signedUrl'] ?? '')
                      : '${attachments[i]}';
                  return GestureDetector(
                    onTap: () => ImageViewerPage.open(ctx, '$url'),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Image.network(
                        '$url',
                        width: 72.r,
                        height: 72.r,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72.r,
                          height: 72.r,
                          color: fg.withValues(alpha: 0.15),
                          child: Icon(Icons.broken_image_outlined,
                              size: 20.sp, color: fg),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (reason == null && description == null)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text('The team is reviewing this delivery.',
                  style: TextStyle(color: fg, fontSize: 12.sp, height: 1.4)),
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
            child: Text('cancelled_reason'.trParams({'reason': deal.cancelReasonLabel ?? ''}),
                style: TextStyle(color: fg, fontSize: 12.sp)),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    switch (deal.status) {
      case DealStatus.pending:
        // website: only the traveler (non-sender) accepts or rejects a pending
        // deal; the sender who proposed it just waits
        if (deal.isSender) return const [];
        return [
          ElevatedButton(
            onPressed: _busy ? null : _acceptDeal,
            child: Text('accept_deal'.tr),
          ),
          SizedBox(height: 12.h),
          OutlinedButton(
            onPressed: _busy ? null : _reject,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.primary,
              side: const BorderSide(color: AppPalette.primary),
            ),
            child: Text('reject_deal'.tr),
          ),
        ];
      case DealStatus.accepted:
        return [
          // sender funds the escrow; traveler films the handover
          if (deal.needsPayment) ...[
            ElevatedButton.icon(
              onPressed: _busy ? null : _payNow,
              icon: Icon(Icons.credit_card, size: 17.sp),
              label: Text('pay_now'.tr),
            ),
            SizedBox(height: 12.h),
          ],
          // the traveler can only start once the sender has paid and their own
          // guarantee (if required) is secured
          if (deal.isTraveler) ...[
            ElevatedButton.icon(
              onPressed: (_busy || !deal.travelerCanStart) ? null : _startOutgoing,
              icon: Icon(Icons.upload_outlined, size: 17.sp),
              label: Text('upload_purchase_video_check_as_ongoing'.tr),
            ),
            SizedBox(height: 12.h),
          ],
          OutlinedButton(
            onPressed: _busy ? null : _cancel,
            child: Text('cancel_deal'.tr),
          ),
        ];
      case DealStatus.outgoing:
        // once the parcel is moving, walking away is a dispute, not a
        // cancel (website: cancel is only offered while ACCEPTED)
        return [
          // the traveler closes the deal at handover: scan the receiver's QR,
          // record the delivery, done — no trip out to the website
          // an open dispute freezes the deal: completing it here would
          // close the dispute behind the resolution process's back
          if (deal.disputeActive) ..._disputeActions()
          else ...[
            if (deal.isTraveler) ...[
              ElevatedButton.icon(
                onPressed: _busy ? null : _scanAndComplete,
                icon: Icon(Icons.qr_code_scanner, size: 18.sp),
                label: Text('scan_receiver_qr_to_complete'.tr),
              ),
              SizedBox(height: 12.h),
            ],
            if (!deal.isTraveler && deal.canMarkCompleted) ...[
              ElevatedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => _repo.markCompleted(deal.refId), 'Marked as completed'),
                child: Text('mark_as_completed'.tr),
              ),
              SizedBox(height: 12.h),
            ],
            _openDisputeButton(),
          ],
        ];
      case DealStatus.completed:
        // only the sender reviews the deal (website: isDealReviewable)
        return [
          if (!deal.isTraveler) ...[
            ElevatedButton(
              onPressed: () => _openRateSheet(context),
              child: Text('rate_this_deal'.tr),
            ),
            SizedBox(height: 12.h),
          ],
          // one dispute per deal — once filed, only its report is offered
          if (deal.hasDisputeRecord) ..._disputeActions() else _openDisputeButton(),
        ];
      case DealStatus.disputes:
        // no "Mark as completed" here: a dispute closes only through the
        // dispute resolution process, never as a side effect of completing
        return _disputeActions();
      case DealStatus.cancelled:
        return [
          OutlinedButton(onPressed: () => Get.back(), child: Text('back_to_deals'.tr)),
        ];
    }
  }

  Widget _openDisputeButton() => OutlinedButton.icon(
        onPressed: _busy ? null : _openDispute,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.primary,
          side: const BorderSide(color: AppPalette.primary),
        ),
        icon: Icon(Icons.gpp_maybe_outlined, size: 17.sp),
        label: Text('open_a_dispute'.tr),
      );

  List<Widget> _disputeActions() => [
        OutlinedButton(
          onPressed: _showDisputeReport,
          child: Text('view_dispute_report'.tr),
        ),
      ];

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
      toast('thanks_for_the_review'.tr);
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
            Text('rate_this_deal'.tr, style: Theme.of(context).textTheme.titleLarge),
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
                  : Text('submit_review'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
