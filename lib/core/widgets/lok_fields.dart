import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_palette.dart';
import '../utils/format.dart';

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

  const LokTextField({
    super.key,
    required this.label,
    required this.hint,
    this.icon,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
    this.controller,
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
  final String label;
  final String hint;
  final TextEditingController? controller;

  const LokPasswordField({
    super.key,
    this.label = 'Password',
    this.hint = 'your password',
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
        _Label(widget.label, required: true),
        TextField(
          controller: widget.controller,
          obscureText: _hidden,
          decoration: InputDecoration(
            hintText: widget.hint,
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
class LokDropdownField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final List<String> options;
  final String? value;
  final bool required;
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
            value ?? hint,
            style: _valueStyle(context, value != null),
          ),
        ),
      ],
    );
  }

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
                    child: const Text('Done'),
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
  final String label;
  final String? fileName;
  final VoidCallback onTap;

  const LokUploadField({
    super.key,
    this.label = 'Upload Product Picture',
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
                fileName ?? label,
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

class LokCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const LokCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          SizedBox(
            width: 24.w,
            height: 24.w,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppPalette.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.r)),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
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
