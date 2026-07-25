import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'core/constants/api_constants.dart';
import 'core/services/cache_service.dart';
import 'core/di/dependency_injection.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Stripe must know the publishable key before any escrow payment sheet opens
  // (sender hold / traveler guarantee on deals). Pushing it to the native SDK
  // up front keeps the first "Pay now" snappy, but nothing here may block the
  // first frame — a throw before runApp() leaves a white screen.
  Stripe.publishableKey = ApiConstants.stripePublishableKey;
  unawaited(Stripe.instance.applySettings().catchError((Object e) {
    debugPrint('stripe init failed: $e'); // the sheet re-applies on demand
  }));

  try {
    // offline cache + core services, ready for the API layer
    await CacheService().init();
    await DependencyInjection.init();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e, s) {
    // never leave the user on a blank screen — start up and let the screens
    // surface whatever failed
    debugPrint('startup failed: $e\n$s');
  }

  runApp(const MyApp());
}
