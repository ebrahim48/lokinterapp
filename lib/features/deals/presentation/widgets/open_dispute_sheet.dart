import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/notify.dart';
import '../../data/deals_repository.dart';
import 'package:get/get.dart';

/// Website parity: the "Open Dispute" dialog. Reasons come from the API
/// per-deal (contextual — ghosting reasons only while OUTGOING), damaged /
/// wrong-item disputes must attach photo or video evidence, and the
/// whole flow is only available inside the dispute window.
class OpenDisputeSheet extends StatefulWidget {
  final int dealId;
  const OpenDisputeSheet({super.key, required this.dealId});

  /// Returns true when a dispute was filed.
  static Future<bool?> show(BuildContext context, int dealId) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (_) => OpenDisputeSheet(dealId: dealId),
    );
  }

  @override
  State<OpenDisputeSheet> createState() => _OpenDisputeSheetState();
}

class _OpenDisputeSheetState extends State<OpenDisputeSheet> {
  final _repo = DealsRepository();
  final _description = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  List<Map<String, dynamic>> _reasons = [];
  String? _selected;
  List<XFile> _evidence = [];
  String? _windowNote;
  bool _windowClosed = false;

  // these reasons can't be judged without seeing the item
  static const _evidenceRequired = {'ITEM_DAMAGED', 'WRONG_ITEM'};

  bool get _needsEvidence => _evidenceRequired.contains(_selected);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reasons = await _repo.disputeReasons(widget.dealId);
      Map<String, dynamic> window = {};
      try {
        window = await _repo.disputeWindow(widget.dealId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _reasons = reasons;
        _loading = false;
        final canDispute = window['canDispute'];
        if (canDispute == false) {
          _windowClosed = true;
          _windowNote = 'The dispute window for this deal has closed.';
        } else if (window['remainingSeconds'] is num) {
          final mins = ((window['remainingSeconds'] as num) / 60).ceil();
          _windowNote = mins > 120
              ? 'Dispute window open — about ${(mins / 60).floor()}h left.'
              : 'Dispute window open — about ${mins}m left.';
        }
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      toastError(e);
    }
  }

  Future<void> _pickEvidence() async {
    final imgs = await ImagePicker().pickMultiImage(maxWidth: 1920, imageQuality: 80);
    if (imgs.isNotEmpty && mounted) setState(() => _evidence = [..._evidence, ...imgs]);
  }

  Future<void> _submit() async {
    if (_selected == null) {
      toast('pick_a_reason_first'.tr);
      return;
    }
    if (_needsEvidence && _evidence.isEmpty) {
      toast('photo_or_video_evidence_is_required_for_this_rea'.tr);
      return;
    }
    setState(() => _sending = true);
    try {
      await _repo.createDispute(
        widget.dealId,
        reason: _selected!,
        description: _description.text.trim(),
        attachmentPaths: _evidence.map((x) => x.path).toList(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      toast('dispute_filed_our_team_will_review_it'.tr);
    } on AppException catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _labelOf(Map<String, dynamic> r) =>
      (r['label'] ?? r['title'] ?? r['name'] ?? _prettify('${r['value'] ?? r['reason'] ?? ''}'))
          .toString();

  // the API returns [{key, label}] — without `key` every reason resolved to the
  // same empty string, so picking one lit them all up and submitting sent none
  String _valueOf(Map<String, dynamic> r) =>
      (r['key'] ?? r['value'] ?? r['reason'] ?? r['code'] ?? '').toString();

  String _prettify(String code) => code
      .split('_')
      .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('open_a_dispute'.tr, style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: 6.h),
              Text(
                'Tell us what went wrong with this delivery. '
                'Funds stay locked until our team decides.',
                style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant, height: 1.4),
              ),
              if (_windowNote != null) ...[
                SizedBox(height: 10.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: _windowClosed
                        ? AppPalette.primary.withValues(alpha: 0.1)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 15.sp,
                          color: _windowClosed ? AppPalette.primary : cs.onSurfaceVariant),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(_windowNote!,
                            style: TextStyle(
                                fontSize: 12.sp,
                                color: _windowClosed
                                    ? AppPalette.primary
                                    : cs.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 14.h),
              if (_loading)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: const Center(child: CircularProgressIndicator()),
                )
              else ...[
                ..._reasons.map((r) {
                  final value = _valueOf(r);
                  final picked = _selected == value;
                  return InkWell(
                    onTap: _windowClosed ? null : () => setState(() => _selected = value),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Row(
                        children: [
                          Icon(
                            picked ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 20.sp,
                            color: picked ? AppPalette.primary : cs.onSurfaceVariant,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(_labelOf(r),
                                style: TextStyle(
                                    fontSize: 13.sp,
                                    color: _windowClosed ? cs.onSurfaceVariant : cs.onSurface)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (_reasons.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Text('no_dispute_reasons_available_for_this_deal'.tr,
                        style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
                  ),
                SizedBox(height: 8.h),
                TextField(
                  controller: _description,
                  maxLines: 3,
                  enabled: !_windowClosed,
                  decoration: const InputDecoration(
                    hintText: 'Describe what happened (optional)',
                  ),
                ),
                SizedBox(height: 12.h),
                GestureDetector(
                  onTap: _windowClosed ? null : _pickEvidence,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                          color: _needsEvidence && _evidence.isEmpty
                              ? AppPalette.primary
                              : cs.outline),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.photo_camera_outlined,
                            size: 18.sp, color: cs.onSurfaceVariant),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            _evidence.isNotEmpty
                                ? '${_evidence.length} photo(s) selected'
                                : _needsEvidence
                                    ? 'Add photo evidence (required)'
                                    : 'Add photo evidence (optional)',
                            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_evidence.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _evidence = []),
                            child: Icon(Icons.clear, size: 18.sp, color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 18.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending || _windowClosed ? null : _submit,
                    child: _sending
                        ? SizedBox(
                            width: 20.r,
                            height: 20.r,
                            child: const CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('send_dispute'.tr),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }
}
