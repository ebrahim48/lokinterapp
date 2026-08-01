class ApiConstants {
  static const String baseUrl = 'https://api.ssh.bd/api/v1';

  /// Deployed web front-end. Deal QR codes encode
  /// `$webBaseUrl/deal-details/{referenceId}` so the receiver's phone
  /// camera opens the website's public confirmation page — same link the
  /// Angular app puts in its QR. (Confirm host before prod release.)
  static const String webBaseUrl = 'https://lokinter.ssh.bd';

  /// Stripe TEST publishable key — must belong to the same Stripe account as
  /// the backend's `STRIPE_SECRET`, or the payment sheet confirms an intent
  /// the server never created. Swap for the pk_live key at production release.
  ///
  /// The SECRET key deliberately lives only in the backend `.env`
  /// (`config/services.php` → `STRIPE_SECRET`). Anything compiled into the APK
  /// is trivially extractable, and a leaked secret key can charge cards and
  /// issue refunds — the app only ever needs the publishable half.
  static const String stripePublishableKey =
      'pk_test_51OEATeKNWVvnHiSQebZv0fZqKlSeJOpkCMxrFydhpJ62nQfaVF3QgyFdFFa4GniAMsWrFPvHh9BGI7Ex1ZrN7Ivp00ivXZpHsx';

  static const Map<String, String> headers = {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };
}
