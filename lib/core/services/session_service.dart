import 'dart:convert';

import 'package:get/get.dart';
import '../../features/auth/data/models/auth_user.dart';
import 'cache_service.dart';
import 'storage_service.dart';

// Who is logged in right now. Tokens live in SharedPreferences so the
// session survives restarts; the interceptor in ApiService reads them here.
class SessionService extends GetxService {
  final StorageService _storage;
  SessionService(this._storage);

  final user = Rxn<AuthUser>();
  String? accessToken;
  String? refreshToken;

  bool get loggedIn => accessToken != null && accessToken!.isNotEmpty;
  bool get isGuest => !loggedIn;

  SessionService restore() {
    accessToken = _storage.getString(StorageKeys.authToken);
    refreshToken = _storage.getString(StorageKeys.refreshToken);
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

  Future<void> setTokens(String? access, String? refresh) async {
    accessToken = access;
    refreshToken = refresh;
    if (access != null) await _storage.setString(StorageKeys.authToken, access);
    if (refresh != null) await _storage.setString(StorageKeys.refreshToken, refresh);
    await _storage.setBool(StorageKeys.isLoggedIn, access != null);
  }

  Future<void> saveUser(AuthUser u) async {
    user.value = u;
    await _storage.setString(StorageKeys.userJson, jsonEncode(u.toJson()));
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    user.value = null;
    await _storage.remove(StorageKeys.authToken);
    await _storage.remove(StorageKeys.refreshToken);
    await _storage.remove(StorageKeys.userJson);
    await _storage.setBool(StorageKeys.isLoggedIn, false);
    await CacheService().clear(); // don't leak one account's data into the next
  }
}
