import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/cache_service.dart';
import 'core/di/dependency_injection.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // offline cache + core services, ready for the API layer
  await CacheService().init();
  await DependencyInjection.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}
