import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../features/lookups/data/lookups_repository.dart';
import '../services/language_service.dart';
import '../theme/app_palette.dart';

// Language switcher (English / French), backed by LanguageService: it persists
// the choice, retranslates the UI, sets the API X-Lang header, and saves the
// preference to the profile when signed in.
const _meta = {
  'en': ('English', '🇬🇧'),
  'fr': ('Français', '🇫🇷'),
};

void showLanguageSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final lang = Get.find<LanguageService>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: cs.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (_) => SafeArea(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        // build from GET /lookups/getLanguages; fall back to the known set
        future: LookupsRepository().languages().catchError((_) => <Map<String, dynamic>>[]),
        builder: (context, snap) {
          final codes = (snap.data
                      ?.map((e) => '${e['code']}')
                      .where(LanguageService.supported.contains)
                      .toList() ??
                  const <String>[])
              .cast<String>();
          final list = codes.isEmpty ? LanguageService.supported : codes;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 6.h),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('common.language'.tr,
                      style: TextStyle(
                          fontSize: 15.sp, fontWeight: FontWeight.w700, color: cs.onSurface)),
                ),
              ),
              Obx(() {
                final current = lang.code.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final code in list)
                      ListTile(
                        leading: Text(_meta[code]?.$2 ?? '🌐',
                            style: TextStyle(fontSize: 20.sp)),
                        title: Text(_meta[code]?.$1 ?? code.toUpperCase()),
                        trailing: code == current
                            ? const Icon(Icons.check, color: AppPalette.primary)
                            : null,
                        onTap: () {
                          lang.setLanguage(code);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                );
              }),
              SizedBox(height: 8.h),
            ],
          );
        },
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
        tooltip: 'common.language'.tr,
        onPressed: () => showLanguageSheet(context),
        icon: const Icon(Icons.language),
      );
    }

    final lang = Get.find<LanguageService>();
    return Obx(() {
      final code = lang.code.value;
      final meta = _meta[code] ?? ('🌐', code.toUpperCase());
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
              Text(meta.$2, style: TextStyle(fontSize: 13.sp)),
              SizedBox(width: 6.w),
              Text(meta.$1,
                  style: TextStyle(
                      fontSize: 12.sp, color: cs.onSurface, fontWeight: FontWeight.w600)),
              Icon(Icons.keyboard_arrow_down, size: 16.sp, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      );
    });
  }
}
