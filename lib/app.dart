import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'core/services/api_service.dart';
import 'core/services/session_service.dart';
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
          home: child,
        );
      },
      child: loggedIn ? const MainShell() : const WelcomePage(),
    );
  }
}
