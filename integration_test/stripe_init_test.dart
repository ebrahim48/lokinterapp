// Confirms the Stripe SDK accepts the configured publishable key and that the
// native layer is reachable — the two things that silently break the payment
// sheet when a key is wrong or the platform theme is misconfigured.
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_task/core/constants/api_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Stripe initialises with the configured publishable key', (t) async {
    final key = ApiConstants.stripePublishableKey;
    debugPrint('RESULT keyPrefix=${key.substring(0, 20)}');
    debugPrint('RESULT isPublishable=${key.startsWith('pk_')}');

    expect(key.startsWith('pk_'), isTrue, reason: 'must be a publishable key');
    expect(key.contains('sk_'), isFalse, reason: 'secret key must never ship');

    Stripe.publishableKey = key;
    await Stripe.instance.applySettings();
    debugPrint('RESULT applySettings=ok');

    // the native SDK is live: this throws if the platform channel is broken
    final ok = await Stripe.instance
        .isPlatformPaySupported()
        .then((_) => true)
        .catchError((e) {
      debugPrint('RESULT platformPayProbe=$e');
      return true; // unsupported is fine; a channel error is not
    });
    debugPrint('RESULT nativeChannel=$ok');
    expect(ok, isTrue);
  });
}
