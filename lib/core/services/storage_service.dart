import 'package:shared_preferences/shared_preferences.dart';

/// A clean-architecture wrapper around [SharedPreferences] for persistent
/// key-value storage.
///
/// [StorageService] is registered as a singleton in [DependencyInjection]
/// and is available app-wide via `Get.find<StorageService>()`.
///
/// **Supported Types:** `String`, `int`, `double`, `bool`, `List<String>`
///
/// **Usage:**
/// ```dart
/// final storage = Get.find<StorageService>();
///
/// // Write
/// await storage.setString(StorageKeys.authToken, 'abc123');
/// await storage.setBool(StorageKeys.isLoggedIn, true);
///
/// // Read
/// final token = storage.getString(StorageKeys.authToken);
/// final isLoggedIn = storage.getBool(StorageKeys.isLoggedIn) ?? false;
///
/// // Remove
/// await storage.remove(StorageKeys.authToken);
///
/// // Clear all stored data
/// await storage.clear();
/// ```
///
/// **Initialization:**
/// Called automatically via [DependencyInjection.init()] before the app runs.
/// Do not call [init] manually unless in tests.
class StorageService {
  late SharedPreferences _prefs;

  /// Initializes the underlying [SharedPreferences] instance.
  ///
  /// This is called once during app startup via [DependencyInjection.init()].
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── String ──────────────────────────────────────────────────────────────

  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  String? getString(String key) => _prefs.getString(key);

  // ─── Int ─────────────────────────────────────────────────────────────────

  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  int? getInt(String key) => _prefs.getInt(key);

  // ─── Double ──────────────────────────────────────────────────────────────

  Future<bool> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  double? getDouble(String key) => _prefs.getDouble(key);

  // ─── Bool ────────────────────────────────────────────────────────────────

  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  bool? getBool(String key) => _prefs.getBool(key);

  // ─── List<String> ────────────────────────────────────────────────────────

  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  List<String>? getStringList(String key) => _prefs.getStringList(key);

  // ─── Utility ─────────────────────────────────────────────────────────────

  /// Returns `true` if [key] exists in storage.
  bool containsKey(String key) => _prefs.containsKey(key);

  /// Removes a single [key] from storage.
  Future<bool> remove(String key) => _prefs.remove(key);

  /// Removes all stored data. Use with caution.
  Future<bool> clear() => _prefs.clear();

  /// Returns every key currently stored.
  Set<String> getKeys() => _prefs.getKeys();
}

/// Predefined key constants for [StorageService].
///
/// Always use these constants instead of raw strings to avoid typos
/// and to have a single source of truth for all storage keys.
///
/// **Usage:**
/// ```dart
/// await storage.setString(StorageKeys.authToken, token);
/// final token = storage.getString(StorageKeys.authToken);
/// ```
///
/// Add new keys here as your feature set grows.
abstract class StorageKeys {
  StorageKeys._();

  // ─── Auth ─────────────────────────────────────────────────────────────────
  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String isLoggedIn = 'is_logged_in';

  // ─── User ─────────────────────────────────────────────────────────────────
  static const String userId = 'user_id';
  static const String userName = 'user_name';
  static const String userEmail = 'user_email';

  // ─── App Settings ─────────────────────────────────────────────────────────
  static const String isDarkMode = 'is_dark_mode';
  static const String selectedLanguage = 'selected_language';
  static const String isFirstLaunch = 'is_first_launch';

  // Add more keys below as needed:
  // static const String fcmToken = 'fcm_token';
  // static const String lastSyncTime = 'last_sync_time';
}
