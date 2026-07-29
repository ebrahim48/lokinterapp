import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/notify.dart';
import '../../data/report_repository.dart';

// "Report Profile" from the chat header — pick a reason, add optional detail.
class ReportProfileSheet extends StatefulWidget {
  final int userId;
  final String userName;

  const ReportProfileSheet({super.key, required this.userId, required this.userName});

  static Future<void> show(BuildContext context, {required int userId, required String userName}) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (_) => ReportProfileSheet(userId: userId, userName: userName),
    );
  }

  @override
  State<ReportProfileSheet> createState() => _ReportProfileSheetState();
}

class _ReportProfileSheetState extends State<ReportProfileSheet> {
  final _details = TextEditingController();
  String? _reason;
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      toast('pick_a_reason_first'.tr);
      return;
    }
    setState(() => _sending = true);
    try {
      await ReportRepository()
          .report(widget.userId, _reason!, comment: _details.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      toast('report_sent_our_team_will_review_it'.tr);
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
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report ${widget.userName}',
                  style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.primary)),
              SizedBox(height: 4.h),
              Text('tell_us_what_went_wrong_reports_are_confidential'.tr,
                  style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
              SizedBox(height: 10.h),
              for (final r in reportReasons)
                InkWell(
                  onTap: () => setState(() => _reason = r.code),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 9.h),
                    child: Row(
                      children: [
                        Icon(
                          _reason == r.code
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20.sp,
                          color: _reason == r.code ? AppPalette.primary : cs.outline,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(r.label,
                              style: TextStyle(fontSize: 13.5.sp, color: cs.onSurface)),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 8.h),
              TextField(
                controller: _details,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Add details (optional)'),
              ),
              SizedBox(height: 18.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      child: Text('cancel'.tr),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _sending ? null : _submit,
                      child: _sending
                          ? SizedBox(
                              width: 18.r,
                              height: 18.r,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text('send_report'.tr),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
