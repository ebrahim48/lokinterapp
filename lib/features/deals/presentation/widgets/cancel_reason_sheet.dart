import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_palette.dart';
import '../../data/deal_model.dart';

// "Why to cancel this deal?" — the API stores the picked code on the deal.
class CancelReasonSheet extends StatefulWidget {
  const CancelReasonSheet({super.key});

  static Future<CancelReason?> show(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<CancelReason>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (_) => const CancelReasonSheet(),
    );
  }

  @override
  State<CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<CancelReasonSheet> {
  CancelReason? _picked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'why_to_cancel_this_deal'.tr,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppPalette.primary,
              ),
            ),
            SizedBox(height: 6.h),
            for (final r in CancelReason.values)
              InkWell(
                onTap: () => setState(() => _picked = r),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 9.h),
                  child: Row(
                    children: [
                      Icon(
                        _picked == r
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20.sp,
                        color: _picked == r ? AppPalette.primary : cs.outline,
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
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    child: Text('close'.tr),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    // stays disabled until a reason is chosen
                    onPressed: _picked == null ? null : () => Get.back(result: _picked),
                    child: Text('confirm_cancel'.tr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
