import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// App language picker. English + French for now (full translation is a later step).
class LanguageSelector extends StatefulWidget {
  const LanguageSelector({super.key});

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  static const _langs = [('English', '🇬🇧'), ('Français', '🇫🇷')];
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lang = _langs[_index];
    return GestureDetector(
      onTap: _open,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lang.$2, style: TextStyle(fontSize: 13.sp)),
            SizedBox(width: 6.w),
            Text(
              lang.$1,
              style: TextStyle(fontSize: 12.sp, color: cs.onSurface, fontWeight: FontWeight.w600),
            ),
            Icon(Icons.keyboard_arrow_down, size: 16.sp, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _open() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _langs.length; i++)
              ListTile(
                leading: Text(_langs[i].$2, style: TextStyle(fontSize: 20.sp)),
                title: Text(_langs[i].$1),
                trailing: i == _index
                    ? const Icon(Icons.check, color: Color(0xFFB85450))
                    : null,
                onTap: () {
                  setState(() => _index = i);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}
