/// Route name constants for the entire application.
///
/// All route names are defined here as static constants. Use these constants
/// everywhere instead of string literals to prevent typos and to get
/// compile-time safety when navigating.
///
/// **Usage:**
/// ```dart
/// // Navigate to a named route
/// Get.toNamed(AppRoutes.home);
///
/// // Navigate and remove all previous routes
/// Get.offAllNamed(AppRoutes.login);
///
/// // Navigate with arguments
/// Get.toNamed(AppRoutes.profile, arguments: {'userId': '123'});
/// ```
///
/// **Adding a new route:**
/// 1. Add the constant here: `static const String profile = '/profile';`
/// 2. Add a [GetPage] entry in [AppPages.routes].
/// 3. Optionally create a [Bindings] class for that page.
abstract class AppRoutes {
  AppRoutes._();

  static const String initial = '/';
  static const String home = '/home';

  // ─── Add your routes below ───────────────────────────────────────────────
  // static const String splash   = '/splash';
  // static const String login    = '/login';
  // static const String register = '/register';
  // static const String profile  = '/profile';
  // static const String settings = '/settings';
  // static const String cart     = '/cart';
  // static const String checkout = '/checkout';
  // static const String orderDetail = '/order-detail';
}
