import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_palette.dart';

// Shared app language (English / French). Full translation is a later step.
final appLanguage = ValueNotifier<int>(0);

const _langs = [('English', '🇬🇧'), ('Français', '🇫🇷')];

void showLanguageSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: cs.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (_) => SafeArea(
      child: ValueListenableBuilder<int>(
        valueListenable: appLanguage,
        builder: (context, current, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _langs.length; i++)
              ListTile(
                leading: Text(_langs[i].$2, style: TextStyle(fontSize: 20.sp)),
                title: Text(_langs[i].$1),
                trailing: i == current ? const Icon(Icons.check, color: AppPalette.primary) : null,
                onTap: () {
                  appLanguage.value = i;
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

class LanguageSelector extends StatelessWidget {
  final bool compact; // compact = globe icon button (app bar)
  const LanguageSelector({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (compact) {
      return IconButton(
        tooltip: 'Language',
        onPressed: () => showLanguageSheet(context),
        icon: const Icon(Icons.language),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: appLanguage,
      builder: (context, current, __) {
        final lang = _langs[current];
        return GestureDetector(
          onTap: () => showLanguageSheet(context),
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
                Text(lang.$1,
                    style: TextStyle(fontSize: 12.sp, color: cs.onSurface, fontWeight: FontWeight.w600)),
                Icon(Icons.keyboard_arrow_down, size: 16.sp, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }
}
