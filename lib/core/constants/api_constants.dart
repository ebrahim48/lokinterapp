class ApiConstants {
  static const String baseUrl = 'https://api.ssh.bd/api/v1';

  /// Deployed web front-end. Deal QR codes encode
  /// `$webBaseUrl/deal-details/{referenceId}` so the receiver's phone
  /// camera opens the website's public confirmation page — same link the
  /// Angular app puts in its QR. (Confirm host before prod release.)
  static const String webBaseUrl = 'https://lokinter.ssh.bd';

  /// Same Stripe TEST publishable key the website dev build uses
  /// (`environment.ts` → stripePublishableKey). Swap for the pk_live key
  /// from `environment.prod.ts` at production release.
  static const String stripePublishableKey =
      'pk_test_51QVtI9GkFypqCloBWPyhkrIxJwR9Q1rVKDHDKc7W4hzEQ6IsMPHtL3u7a9ODjJkxi6GoBEmqePxFYFemcFdxRAfv00QMav0txp';

  static const Map<String, String> headers = {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };
}
