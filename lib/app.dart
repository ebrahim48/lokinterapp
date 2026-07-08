import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'core/theme/lokinter_theme.dart';
import 'features/auth/presentation/welcome_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      child: const WelcomePage(),
    );
  }
}
