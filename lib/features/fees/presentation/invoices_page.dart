import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/notify.dart';
import '../data/fee_models.dart';
import '../data/fees_repository.dart';

/// Invoices & tax records (REQ §15.1 · GUIDE Screen 11): one consolidated
/// invoice per fee payment. Cards show only the invoice number, the standard
/// description, the total, the payment date and status — never deal numbers,
/// customer names or shipment contents.
class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _repo = FeesRepository();
  List<FeeInvoice>? _items;
  String? _error;
  int? _downloading;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.invoices();
      if (mounted) {
        setState(() {
          _items = list;
          _error = null;
        });
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _download(FeeInvoice inv) async {
    if (_downloading != null) return;
    setState(() => _downloading = inv.id);
    try {
      final (url, file) = await _repo.downloadInvoice(inv);
      if (url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else if (file != null) {
        // hands the PDF to the system — open in a PDF viewer, save or send
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: inv.number,
        ));
      }
    } on AppException catch (e) {
      toastError(e);
    } catch (_) {
      toast('could_not_open_invoice'.tr);
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('invoices_tax_records'.tr)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Builder(builder: (context) {
          if (_items == null && _error == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_items == null) {
            return ListView(children: [
              SizedBox(height: 120.h),
              Center(child: Text(_error!)),
              Center(child: TextButton(onPressed: _load, child: Text('retry'.tr))),
            ]);
          }
          if (_items!.isEmpty) {
            return ListView(children: [
              SizedBox(height: 120.h),
              Icon(Icons.receipt_long_outlined, size: 44.sp, color: cs.onSurfaceVariant),
              SizedBox(height: 10.h),
              Center(child: Text('no_invoices_yet'.tr)),
            ]);
          }
          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: _items!.length,
            separatorBuilder: (_, _) => SizedBox(height: 12.h),
            itemBuilder: (_, i) => _card(context, _items![i]),
          );
        }),
      ),
    );
  }

  Widget _card(BuildContext context, FeeInvoice inv) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(inv.number,
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: (inv.isPaid ? const Color(0xFF15803D) : const Color(0xFFD97706))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(inv.isPaid ? 'invoice_paid'.tr : inv.status,
                    style: TextStyle(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w700,
                        color: inv.isPaid ? const Color(0xFF15803D) : const Color(0xFFD97706))),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(inv.description,
              style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant)),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('total_amount_paid'.tr,
                        style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                    Text(inv.totalLabel,
                        style: TextStyle(
                            fontSize: 14.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  ],
                ),
              ),
              if (inv.paidAt != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('payment_date'.tr,
                        style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                    Text(shortDate(inv.paidAt!),
                        style: TextStyle(fontSize: 12.5.sp, color: cs.onSurface)),
                  ],
                ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _downloading == null ? () => _download(inv) : null,
              icon: _downloading == inv.id
                  ? SizedBox(
                      width: 16.r,
                      height: 16.r,
                      child: const CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.download_outlined, size: 17.sp),
              label: Text('download_invoice'.tr),
            ),
          ),
        ],
      ),
    );
  }
}
