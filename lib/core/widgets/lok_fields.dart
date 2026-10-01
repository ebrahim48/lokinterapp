import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_palette.dart';
import '../utils/format.dart';
import 'package:get/get.dart';

class _Label extends StatelessWidget {
  final String text;
  final bool required;
  const _Label(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h, left: 2.w),
      child: Text.rich(
        TextSpan(
          text: text,
          children: required
              ? [const TextSpan(text: ' *', style: TextStyle(color: AppPalette.primary))]
              : null,
        ),
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class LokTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData? icon;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final bool readOnly;

  const LokTextField({
    super.key,
    required this.label,
    required this.hint,
    this.icon,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.controller,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label, required: required),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: readOnly
              ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
              : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon, size: 18.sp),
          ),
        ),
      ],
    );
  }
}

class LokPasswordField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;

  const LokPasswordField({
    super.key,
    this.label,
    this.hint,
    this.controller,
  });

  @override
  State<LokPasswordField> createState() => _LokPasswordFieldState();
}

class _LokPasswordFieldState extends State<LokPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(widget.label ?? 'password'.tr, required: true),
        TextField(
          controller: widget.controller,
          obscureText: _hidden,
          decoration: InputDecoration(
            hintText: widget.hint ?? 'your_password'.tr,
            prefixIcon: Icon(Icons.lock_outline, size: 18.sp),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidden = !_hidden),
              icon: Icon(_hidden ? Icons.visibility_off : Icons.visibility, size: 18.sp),
            ),
          ),
        ),
      ],
    );
  }
}

// Tap-to-pick dropdown backed by a bottom sheet. Selection is local UI state.
// Pass [searchable: true] to show a search bar inside the sheet — useful for
// long lists like countries (190+ entries).
class LokDropdownField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final List<String> options;
  final String? value;
  final bool required;
  final bool searchable;
  final ValueChanged<String> onChanged;

  const LokDropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.options,
    required this.onChanged,
    this.value,
    this.required = false,
    this.searchable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label, required: required),
        _FieldBox(
          icon: icon,
          onTap: () => searchable ? _openSearchable(context) : _open(context),
          trailing: const Icon(Icons.keyboard_arrow_down),
          child: Text(
            value ?? hint,
            style: _valueStyle(context, value != null),
          ),
        ),
      ],
    );
  }

  // ── Plain list (short lists, no search needed) ────────────────────────────
  void _open(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: 12.h),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
              child: Text(label, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (options.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 28.h),
                child: const Center(child: CircularProgressIndicator()),
              ),
            for (final o in options)
              ListTile(
                title: Text(o),
                trailing: o == value
                    ? const Icon(Icons.check, color: AppPalette.primary)
                    : null,
                onTap: () {
                  onChanged(o);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Searchable list (long lists, e.g. countries) ──────────────────────────
  void _openSearchable(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => _SearchableSheet(
        label: label,
        options: options,
        selected: value,
        onSelected: (picked) {
          onChanged(picked);
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Internal stateful sheet that holds the search query and filters the list.
class _SearchableSheet extends StatefulWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _SearchableSheet({
    required this.label,
    required this.options,
    required this.onSelected,
    this.selected,
  });

  @override
  State<_SearchableSheet> createState() => _SearchableSheetState();
}

class _SearchableSheetState extends State<_SearchableSheet> {
  final _searchCtrl = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.options;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.options
          : widget.options.where((o) => o.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 85% of the screen height so the keyboard doesn't push content out
    final maxH = MediaQuery.of(context).size.height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 12.h),
            child: Text(widget.label, style: Theme.of(context).textTheme.titleLarge),
          ),
          // ── Search bar ───────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchCtrl,
              builder: (_, val, __) => TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'search'.tr,
                  prefixIcon: Icon(Icons.search, size: 18.sp),
                  suffixIcon: val.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, size: 16.sp),
                          onPressed: () {
                            _searchCtrl.clear();
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          const Divider(height: 1),
          // ── List ─────────────────────────────────────────────────────────
          Flexible(
            child: widget.options.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 28.h),
                    child: const Center(child: CircularProgressIndicator()),
                  )
                : _filtered.isEmpty
                    ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 28.h),
                        child: Center(
                          child: Text(
                            'no_results_found'.tr,
                            style: TextStyle(
                                fontSize: 13.sp, color: cs.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final o = _filtered[i];
                          return ListTile(
                            title: Text(o),
                            trailing: o == widget.selected
                                ? const Icon(Icons.check, color: AppPalette.primary)
                                : null,
                            onTap: () => widget.onSelected(o),
                          );
                        },
                      ),
          ),
          // bottom safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// Multi-select backed by a checkbox bottom sheet; shows chosen values as chips.
class LokMultiSelectField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final List<String> options;
  final List<String> selected;
  final bool required;
  final ValueChanged<List<String>> onChanged;

  const LokMultiSelectField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label, required: required),
        _FieldBox(
          icon: icon,
          onTap: () => _open(context),
          trailing: const Icon(Icons.keyboard_arrow_down),
          child: Text(
            selected.isEmpty ? hint : '${selected.length} selected',
            style: _valueStyle(context, selected.isNotEmpty),
          ),
        ),
        if (selected.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                for (final s in selected)
                  Chip(
                    label: Text(s, style: TextStyle(fontSize: 11.sp)),
                    onDeleted: () => onChanged(selected.where((e) => e != s).toList()),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _open(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final draft = [...selected];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(label, style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in options)
                      CheckboxListTile(
                        value: draft.contains(o),
                        activeColor: AppPalette.primary,
                        title: Text(o),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => setSheet(() {
                          v == true ? draft.add(o) : draft.remove(o);
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20.w),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      onChanged(draft);
                      Navigator.pop(context);
                    },
                    child: Text('done'.tr),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LokDateField extends StatelessWidget {
  final String label;
  final String hint;
  final DateTime? value;
  final bool required;
  final bool withTime; // also pick a time (used for local trips/requests)
  final ValueChanged<DateTime> onChanged;

  const LokDateField({
    super.key,
    required this.label,
    required this.hint,
    required this.onChanged,
    this.value,
    this.required = false,
    this.withTime = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label, required: required),
        _FieldBox(
          icon: withTime ? Icons.schedule : Icons.event_outlined,
          onTap: () => _pick(context),
          child: Text(
            value == null ? hint : (withTime ? shortDateTime(value!) : shortDate(value!)),
            style: _valueStyle(context, value != null),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (date == null) return;

    if (!withTime) {
      onChanged(date);
      return;
    }

    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: value == null ? TimeOfDay.now() : TimeOfDay.fromDateTime(value!),
    );
    onChanged(DateTime(date.year, date.month, date.day, time?.hour ?? 0, time?.minute ?? 0));
  }
}

class LokUploadField extends StatelessWidget {
  final String? label;
  final String? fileName;
  final VoidCallback onTap;

  const LokUploadField({
    super.key,
    this.label,
    this.fileName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: DottedBorderBox(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.file_upload_outlined, size: 18.sp, color: cs.onSurfaceVariant),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                fileName ?? label ?? 'upload_product_picture'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Checkbox with a one-line label. When [linkText] is part of that label and
/// [onLinkTap] is given, that phrase becomes a tappable link — how the terms
/// checkbox opens the terms document without a second row of chrome.
class LokCheckbox extends StatefulWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? linkText;
  final VoidCallback? onLinkTap;

  const LokCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.linkText,
    this.onLinkTap,
  });

  @override
  State<LokCheckbox> createState() => _LokCheckboxState();
}

class _LokCheckboxState extends State<LokCheckbox> {
  final _tap = TapGestureRecognizer();

  @override
  void initState() {
    super.initState();
    _tap.onTap = () => widget.onLinkTap?.call();
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant);
    return InkWell(
      onTap: () => widget.onChanged(!widget.value),
      child: Row(
        children: [
          SizedBox(
            width: 24.w,
            height: 24.w,
            child: Checkbox(
              value: widget.value,
              onChanged: (v) => widget.onChanged(v ?? false),
              activeColor: AppPalette.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(child: _label(style)),
        ],
      ),
    );
  }

  Widget _label(TextStyle style) {
    final link = widget.linkText;
    final at = (link == null || widget.onLinkTap == null)
        ? -1
        : widget.label.toLowerCase().indexOf(link.toLowerCase());
    if (at < 0) return Text(widget.label, style: style);

    return Text.rich(TextSpan(style: style, children: [
      TextSpan(text: widget.label.substring(0, at)),
      TextSpan(
        text: widget.label.substring(at, at + link!.length),
        recognizer: _tap,
        style: TextStyle(
          color: AppPalette.primary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: AppPalette.primary,
        ),
      ),
      TextSpan(text: widget.label.substring(at + link.length)),
    ]));
  }
}

// shared box used by dropdown/date fields so they match text inputs
class _FieldBox extends StatelessWidget {
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final VoidCallback onTap;

  const _FieldBox({
    required this.icon,
    required this.child,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18.sp, color: cs.onSurfaceVariant),
            SizedBox(width: 12.w),
            Expanded(child: child),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: cs.outline),
      ),
      child: child,
    );
  }
}

TextStyle _valueStyle(BuildContext context, bool filled) {
  final cs = Theme.of(context).colorScheme;
  return TextStyle(
    fontSize: 13.sp,
    color: filled ? cs.onSurface : cs.onSurfaceVariant,
  );
}
