import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'notify.dart';

/// Opens Stripe's native payment sheet for [clientSecret].
///
/// Returns true once the card is confirmed, false on cancel or failure. Shared
/// by escrow deal payments and the transporter subscription so both behave
/// identically — same merchant name, same cancel handling, same error copy.
Future<bool> presentStripeSheet(String clientSecret) async {
  try {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Lokinter',
        style: ThemeMode.light,
      ),
    );
    await Stripe.instance.presentPaymentSheet();
    return true;
  } on StripeException catch (e) {
    // a deliberate cancel isn't an error worth shouting about
    if (e.error.code != FailureCode.Canceled) {
      toast(e.error.localizedMessage ?? 'card_confirmation_failed'.tr);
    }
    return false;
  } catch (e) {
    // native SDK misconfigured or the plugin channel died — without this the
    // button would just look dead
    debugPrint('stripe sheet failed: $e');
    toast('could_not_open_the_payment_sheet_try_again'.tr);
    return false;
  }
}

/// Pulls the client secret out of a create-intent response, whichever key the
/// endpoint uses. Empty when the backend settled the payment server-side and
/// there is no card step to run.
String clientSecretOf(Map<String, dynamic> res) =>
    '${res['clientSecret'] ?? res['client_secret'] ?? ''}';
