import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_palette.dart';

/// Scans the recipient's QR and hands back exactly what it encodes.
///
/// New deals carry a single-use delivery token (REQ §3); deals created before
/// tokens carry `{webBaseUrl}/deal-details/{referenceId}`. The deal page tells
/// the two apart — see [isLegacyDealLink] / [referenceFromLink].
class ScanDeliveryPage extends StatefulWidget {
  const ScanDeliveryPage({super.key});

  static Future<String?> open(BuildContext context) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const ScanDeliveryPage()),
      );

  @override
  State<ScanDeliveryPage> createState() => _ScanDeliveryPageState();
}

class _ScanDeliveryPageState extends State<ScanDeliveryPage> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final code in capture.barcodes) {
      final raw = (code.rawValue ?? '').trim();
      if (raw.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('scan_receiver_qr'.tr),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // viewfinder
          Container(
            width: 240.r,
            height: 240.r,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2),
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          Positioned(
            bottom: 60.h,
            left: 24.w,
            right: 24.w,
            child: Text(
              'point_camera_at_receiver_qr'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 13.sp, height: 1.4),
            ),
          ),
          Positioned(
            top: 16.h,
            right: 20.w,
            child: IconButton(
              onPressed: () => _controller.toggleTorch(),
              icon: Icon(Icons.flashlight_on_outlined,
                  color: AppPalette.primary, size: 26.sp),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pre-token QR: the public `deal-details/{referenceId}` link.
bool isLegacyDealLink(String raw) => raw.contains('deal-details/');

/// The reference inside a legacy link (or a bare reference code).
String? referenceFromLink(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  final match = RegExp(r'deal-details/([^/?#\s]+)').firstMatch(value);
  if (match != null) return match.group(1);
  return value.contains('/') ? value.split('/').last : value;
}
