import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'core/services/api_service.dart';
import 'core/services/session_service.dart';
import 'core/i18n/app_translations.dart';
import 'core/services/language_service.dart';
import 'core/services/socket_service.dart';
import 'core/theme/lokinter_theme.dart';
import 'features/auth/presentation/welcome_page.dart';
import 'features/shell/presentation/main_shell.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    ApiService.onSessionExpired = () {
      Get.find<SocketService>().disconnect();
      Get.offAll(() => const WelcomePage());
    };
    final loggedIn = Get.find<SessionService>().loggedIn;

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          title: 'Lokinter',
          debugShowCheckedModeBanner: false,
          theme: LokinterTheme.light,
          darkTheme: LokinterTheme.dark,
          themeMode: ThemeMode.light, // toggle from the app bar
          translations: AppTranslations(),
          locale: Get.find<LanguageService>().locale,
          fallbackLocale: const Locale(LanguageService.fallback),
          // built-in widget text (date/time pickers, dialogs, text selection)
          // follows the app language too
          supportedLocales: [
            for (final c in LanguageService.supported) Locale(c),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: child,
        );
      },
      child: loggedIn ? const MainShell() : const WelcomePage(),
    );
  }
}
