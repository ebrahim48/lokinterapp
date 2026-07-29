import 'dart:async';
import 'dart:ui';

import 'package:get/get.dart';
import 'api_service.dart';
import 'data_bus.dart';
import 'session_service.dart';
import 'storage_service.dart';

// Single source of truth for the app language (en | fr).
// - persists the choice locally (survives logout)
// - drives GetX translations + the API X-Lang/Accept-Language headers
// - restores from the signed-in user's saved preference
class LanguageService extends GetxService {
  static const fallback = 'en';
  static const supported = ['en', 'fr'];

  final StorageService _storage;
  LanguageService(this._storage);

  final code = fallback.obs;

  // read synchronously by the API interceptor on every request
  static String currentCode = fallback;

  Locale get locale => Locale(code.value);

  // called at startup before runApp — restores the last chosen language
  LanguageService restore() {
    final saved = _storage.getString(StorageKeys.selectedLanguage);
    final start = supported.contains(saved) ? saved! : fallback;
    code.value = start;
    currentCode = start;
    return this;
  }

  void _apply(String c, {bool persist = true}) {
    if (!supported.contains(c)) return;
    code.value = c;
    currentCode = c;
    Get.updateLocale(Locale(c));
    if (persist) _storage.setString(StorageKeys.selectedLanguage, c);
  }

  // from a login/register/getUser payload — the server preference wins on the
  // authoritative fetches, but a local pick still persists across restarts
  void applyFromUser(String? lang) {
    if (lang != null && supported.contains(lang) && lang != code.value) {
      _apply(lang);
    }
  }

  // user tapped a language in the picker
  Future<void> setLanguage(String c) async {
    if (c == code.value) return;
    _apply(c);
    // logged in → save to the profile so other sessions inherit it
    final session = Get.find<SessionService>();
    if (session.loggedIn) {
      unawaited(_saveToProfile(c));
    }
    // CMS/home text is server-localized — reload it under the new locale
    DataBus.changed(DataTopic.language);
  }

  Future<void> _saveToProfile(String lang) async {
    final u = Get.find<SessionService>().user.value;
    if (u == null) return;
    final parts = u.fullName.trim().split(RegExp(r'\s+'));
    final first = (u.firstName?.trim().isNotEmpty ?? false)
        ? u.firstName!
        : (parts.isNotEmpty ? parts.first : '');
    final last = (u.lastName?.trim().isNotEmpty ?? false)
        ? u.lastName!
        : (parts.length > 1 ? parts.sublist(1).join(' ') : '');
    // required profile fields must ride along; the X-Lang header already makes
    // the current session French, so a failure here is non-fatal
    try {
      await Get.find<ApiService>().post('/auth/updateProfile', data: {
        'firstName': first,
        'lastName': last,
        'country': u.country ?? '',
        'email': u.email,
        'phone': u.phone ?? '',
        'lang': lang,
      });
    } catch (_) {}
  }
}
