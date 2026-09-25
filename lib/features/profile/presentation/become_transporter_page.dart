import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/notify.dart';
import '../../../core/widgets/lok_busy_button.dart';
import '../../../core/widgets/lok_fields.dart';
import '../../lookups/data/lookup_models.dart';
import '../../lookups/data/lookups_repository.dart';
import '../data/visibility_repository.dart';
import 'controllers/profile_controller.dart';

/// Lets an existing sender/traveler apply to become a transporter. The same
/// details signup collects, but for an account that already exists — the
/// request goes to `pending` for admin review.
class BecomeTransporterPage extends StatefulWidget {
  const BecomeTransporterPage({super.key});

  @override
  State<BecomeTransporterPage> createState() => _BecomeTransporterPageState();
}

class _BecomeTransporterPageState extends State<BecomeTransporterPage> {
  final _repo = VisibilityRepository();
  final _lookups = LookupsRepository();

  final _legalName = TextEditingController();
  final _address = TextEditingController();
  final _countries = <String>[].obs;
  final _busy = false.obs;

  List<Country> _all = [];
  PlatformFile? _license;
  PlatformFile? _legalDoc;

  @override
  void initState() {
    super.initState();
    // show what the server already holds when an application exists
    final user = Get.find<SessionService>().user.value;
    _legalName.text = user?.legalName ?? '';
    _address.text = user?.address ?? '';
    _lookups.countries().then((list) {
      if (!mounted) return;
      setState(() {
        _all = list;
        final saved = user?.operatingCountries ?? const [];
        _countries.assignAll(list
            .where((c) => saved.contains(c.iso2))
            .map((c) => c.name));
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _legalName.dispose();
    _address.dispose();
    super.dispose();
  }

  List<String> get _countryNames => _all.map((e) => e.name).toList();

  // ISO2 is what the API stores for operating countries
  List<String> get _selectedIso => _countries
      .map((n) => _all.firstWhereOrNull((c) => c.name == n)?.iso2)
      .whereType<String>()
      .toList();

  Future<void> _pick(bool license) async {
    FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
    } catch (_) {
      toast('could_not_open_the_file_picker'.tr);
      return;
    }
    final f = (res?.files.isNotEmpty ?? false) ? res!.files.first : null;
    if (f == null || f.path == null) return;
    if (f.size > 10 * 1024 * 1024) {
      toast('each_document_must_be_10_mb_or_smaller'.tr);
      return;
    }
    setState(() => license ? _license = f : _legalDoc = f);
  }

  Future<void> _submit() async {
    if (_legalName.text.trim().isEmpty || _address.text.trim().isEmpty) {
      toast('add_your_legal_name_and_business_address'.tr);
      return;
    }
    if (_selectedIso.isEmpty) {
      toast('pick_at_least_one_country_of_operation'.tr);
      return;
    }
    if (_license?.path == null || _legalDoc?.path == null) {
      toast('upload_both_documents'.tr);
      return;
    }

    _busy.value = true;
    try {
      await _repo.requestTransporterVerification(
        legalName: _legalName.text.trim(),
        address: _address.text.trim(),
        operatingCountries: _selectedIso,
        transportLicensePath: _license!.path!,
        legalDocumentPath: _legalDoc!.path!,
      );
      // reflect the pending state without needing a restart
      if (Get.isRegistered<ProfileController>()) {
        await Get.find<ProfileController>().load();
      }
      toast('transporter_request_submitted'.tr);
      Get.back();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      _busy.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = Get.find<SessionService>().user.value;

    // Primary status from API — drives everything below.
    // "none" and null both mean no application on file.
    final status = user?.transporterVerificationStatus; // null | pending | approved | rejected
    final isPending  = status == 'pending';
    final isApproved = user?.isApprovedTransporter == true ||
                       user?.transporterBadge      == true ||
                       status == 'approved';
    final isRejected = status == 'rejected';
    final rejectionReason = user?.transporterRejectionReason;

    return Scaffold(
      appBar: AppBar(title: Text('become_a_transporter'.tr)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        children: [
          // ── REJECTED banner ──────────────────────────────────────
          if (isRejected) ...[
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppPalette.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppPalette.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: AppPalette.primary, size: 20.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('transporter_request_rejected'.tr,
                            style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.primary)),
                        if ((rejectionReason ?? '').isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(rejectionReason!,
                              style: TextStyle(
                                  fontSize: 12.sp,
                                  color: cs.onSurfaceVariant,
                                  height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),
          ],

          // ── APPROVED banner ───────────────────────────────────────
          if (isApproved) ...[
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppPalette.verified.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppPalette.verified.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppPalette.verified, size: 20.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text('you_are_already_a_transporter'.tr,
                        style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),
          ],

          // ── PENDING banner ────────────────────────────────────────
          if (isPending && !isApproved) ...[
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppPalette.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppPalette.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top, color: AppPalette.primary, size: 20.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text('transporter_request_pending'.tr,
                        style: TextStyle(fontSize: 12.5.sp, color: cs.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),
          ],
          Text(
            'documents_are_reviewed_by_our_team_before_your_t'.tr,
            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.5),
          ),
          SizedBox(height: 20.h),
          LokTextField(
            label: 'legal_name'.tr,
            hint: 'business_legal_name'.tr,
            icon: Icons.badge_outlined,
            required: true,
            controller: _legalName,
          ),
          SizedBox(height: 16.h),
          LokTextField(
            label: 'address'.tr,
            hint: 'business_address'.tr,
            icon: Icons.location_city_outlined,
            required: true,
            controller: _address,
          ),
          SizedBox(height: 16.h),
          Obx(() => LokMultiSelectField(
                label: 'countries_of_operation'.tr,
                hint: 'select_countries'.tr,
                icon: Icons.public,
                required: true,
                options: _countryNames,
                selected: _countries.toList(),
                onChanged: _countries.assignAll,
              )),
          SizedBox(height: 16.h),
          LokUploadField(
            label: 'upload_transport_license'.tr,
            fileName: _license?.name,
            onTap: () => _pick(true),
          ),
          SizedBox(height: 12.h),
          LokUploadField(
            label: 'upload_legal_documents'.tr,
            fileName: _legalDoc?.name,
            onTap: () => _pick(false),
          ),
          SizedBox(height: 22.h),
          // Button is ALWAYS visible — state driven by transporterVerificationStatus
          // + isApprovedTransporter / transporterBadge:
          //   none / null  → Submit (enabled)
          //   pending      → disabled, shows "Pending Review"
          //   approved     → disabled, shows "Accepted"  (uses isApprovedTransporter too)
          //   rejected     → Re-apply (enabled)
          Obx(() {
            final u = Get.find<SessionService>().user.value;
            final st = u?.transporterVerificationStatus;
            final approved = u?.isApprovedTransporter == true ||
                             u?.transporterBadge      == true ||
                             st == 'approved';
            if (approved) {
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  child: Text('accepted'.tr),
                ),
              );
            }
            if (st == 'pending') {
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  child: Text('pending_review'.tr),
                ),
              );
            }
            // null (none) or rejected → allow apply / re-apply
            return LokBusyButton(
              busy: _busy,
              label: st == 'rejected' ? 'reapply'.tr : 'submit_request'.tr,
              onPressed: _submit,
            );
          }),
        ],
      ),
    );
  }
}
