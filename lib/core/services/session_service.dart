import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import '../../features/auth/data/models/auth_user.dart';
import 'cache_service.dart';
import 'language_service.dart';
import 'storage_service.dart';

// Who is logged in right now. Tokens live in secure storage (Keychain /
// Keystore) so the session survives restarts and reboots; the interceptor in
// ApiService reads them here and refreshes them when they expire.
class SessionService extends GetxService {
  final StorageService _storage;
  SessionService(this._storage);

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final user = Rxn<AuthUser>();
  String? accessToken;
  String? refreshToken;

  bool get loggedIn => accessToken != null && accessToken!.isNotEmpty;
  bool get isGuest => !loggedIn;

  Future<SessionService> restore() async {
    await _restoreTokens();
    final raw = _storage.getString(StorageKeys.userJson);
    if (raw != null) {
      try {
        user.value = AuthUser.fromJson(jsonDecode(raw));
      } catch (_) {}
    }
    return this;
  }

  // login/register both return the same user + token payload
  Future<void> saveLogin(Map<String, dynamic> data) async {
    final token = data['token'] ?? {};
    await setTokens(token['accessToken'], token['refreshToken']);
    await saveUser(AuthUser.fromJson(data));
  }

  Future<void> _restoreTokens() async {
    // the Keychain outlives an uninstall, prefs don't — without the prefs flag
    // these tokens belong to a previous install, so drop them
    if (_storage.getBool(StorageKeys.isLoggedIn) != true) {
      await _deleteSecureTokens();
      return;
    }
    try {
      accessToken = await _secure.read(key: StorageKeys.authToken);
      refreshToken = await _secure.read(key: StorageKeys.refreshToken);
    } catch (_) {
      // unreadable keystore (e.g. restored backup) — fall through to prefs
    }
    // older builds kept the tokens in SharedPreferences: move them over once
    final legacyAccess = _storage.getString(StorageKeys.authToken);
    final legacyRefresh = _storage.getString(StorageKeys.refreshToken);
    if (legacyAccess != null || legacyRefresh != null) {
      accessToken ??= legacyAccess;
      refreshToken ??= legacyRefresh;
      await _writeSecureTokens(accessToken, refreshToken);
      await _storage.remove(StorageKeys.authToken);
      await _storage.remove(StorageKeys.refreshToken);
    }
  }

  Future<void> setTokens(String? access, String? refresh) async {
    accessToken = access;
    refreshToken = refresh;
    await _writeSecureTokens(access, refresh);
    await _storage.setBool(StorageKeys.isLoggedIn, access != null);
  }

  Future<void> _writeSecureTokens(String? access, String? refresh) async {
    try {
      if (access != null) {
        await _secure.write(key: StorageKeys.authToken, value: access);
      }
      if (refresh != null) {
        await _secure.write(key: StorageKeys.refreshToken, value: refresh);
      }
    } catch (_) {
      // keep the in-memory session even if the keystore write fails
    }
  }

  Future<void> _deleteSecureTokens() async {
    try {
      await _secure.delete(key: StorageKeys.authToken);
      await _secure.delete(key: StorageKeys.refreshToken);
    } catch (_) {}
  }

  Future<void> saveUser(AuthUser u) async {
    user.value = u;
    await _storage.setString(StorageKeys.userJson, jsonEncode(u.toJson()));
    // adopt the account's saved language on login / getUser
    if (Get.isRegistered<LanguageService>()) {
      Get.find<LanguageService>().applyFromUser(u.lang);
    }
  }

  // wipes every trace of the account so nothing leaks into the next login
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    user.value = null;
    await _deleteSecureTokens();
    await _storage.clearAccountData(); // all account prefs (user, flags, …)
    await CacheService().clear(); // Hive: deals, posts, chat inbox, home feed
    await _clearImageCache(); // cached avatars / item photos
  }

  Future<void> _clearImageCache() async {
    try {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      // on-disk cached images — can be slow, so it never holds up logout
      unawaited(DefaultCacheManager().emptyCache().catchError((_) {}));
    } catch (_) {
      // never let cache cleanup block a logout
    }
  }
}
