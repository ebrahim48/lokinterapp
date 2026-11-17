import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/notify.dart';
import '../../data/deal_model.dart';
import '../../data/deals_repository.dart';

/// The sender's handover QR (REQ §3 · GUIDE Screen 4).
///
/// It encodes the single-use `deliveryQrToken`; the sender shares it with
/// whoever collects the parcel — no Lokinter account needed — and can revoke
/// it at any time, which kills every screenshot already sent. Deals created
/// before tokens existed keep the old public-link QR and no regenerate.
class HandoverQrCard extends StatefulWidget {
  final Deal deal;

  /// Called after a successful regenerate so the page reloads the deal.
  final VoidCallback onRegenerated;

  const HandoverQrCard({
    super.key,
    required this.deal,
    required this.onRegenerated,
  });

  @override
  State<HandoverQrCard> createState() => _HandoverQrCardState();
}

class _HandoverQrCardState extends State<HandoverQrCard> {
  final _repo = DealsRepository();
  final _shareKey = GlobalKey();
  bool _busy = false;

  /// The fresh token right after a regenerate, before the reload lands.
  String? _override;

  String get _data => _override ?? widget.deal.handoverQrData;
  bool get _hasToken =>
      _override != null || widget.deal.extras.deliveryQrToken != null;

  @override
  void didUpdateWidget(HandoverQrCard old) {
    super.didUpdateWidget(old);
    // the reload carries the new token — the override has done its job
    if (widget.deal.extras.deliveryQrToken != old.deal.extras.deliveryQrToken) {
      _override = null;
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _renderPng(_data);
      final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: 'share_qr_message'.tr,
          subject: 'lokinter_delivery_qr'.tr,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      toast('could_not_share_qr'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Black-on-white PNG — a transparent QR is unreadable on dark chat themes.
  Future<File> _renderPng(String data) async {
    const size = 900.0, pad = 60.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = Colors.white,
    );
    canvas.translate(pad, pad);
    QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    ).paint(canvas, const Size(size - 2 * pad, size - 2 * pad));
    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/lokinter_delivery_qr_${widget.deal.id}.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _regenerate() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('regenerate_qr_code'.tr),
        content: Text('regenerate_qr_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'regenerate'.tr,
              style: const TextStyle(color: AppPalette.primary),
            ),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final token = await _repo.regenerateQr(widget.deal.id);
      if (!mounted) return;
      setState(() => _override = token);
      toast('qr_regenerated'.tr);
      widget.onRegenerated();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Text(
            'receiver_confirmation'.tr,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            _hasToken ? 'handover_qr_hint'.tr : 'receiver_qr_hint'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
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
              data: _data,
              size: 180.r,
              backgroundColor: Colors.white,
            ),
          ),
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: _shareKey,
              onPressed: _busy ? null : _share,
              icon: Icon(Icons.ios_share, size: 17.sp),
              label: Text('share_qr_code'.tr),
            ),
          ),
          if (_hasToken) ...[
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _regenerate,
                icon: Icon(Icons.refresh, size: 17.sp),
                label: Text('regenerate_qr_code'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
