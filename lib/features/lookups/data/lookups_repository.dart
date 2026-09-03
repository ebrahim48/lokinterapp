import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/services/language_service.dart';
import 'lookup_models.dart';

// Countries / cities / categories barely change, so they're cached hard:
// serve from Hive when present and refresh silently in the background.
class LookupsRepository {
  final _api = Get.find<ApiService>();
  final _cache = CacheService();

  // v2: the model now carries phonecode, so old cache is ignored on upgrade
  static const _countriesKey = 'lookup_countries_v2';

  Future<List<Country>> countries() async {
    final cached = _readList(_countriesKey, Country.fromJson);
    if (cached.isNotEmpty) {
      _refreshCountries(); // fire and forget
      return cached;
    }
    // like the website: a bundled list first for reliability (and it carries
    // the phone codes), API only as a fallback
    final bundled = await _bundledList('assets/data/countries.json', Country.fromJson);
    if (bundled.isNotEmpty) {
      await _writeList(_countriesKey, bundled.map((e) => e.toJson()).toList());
      return bundled;
    }
    return _refreshCountries();
  }

  Future<List<Country>> _refreshCountries() async {
    final res = await _api.get('/countries/getAllCountries');
    final list = _asList(unwrapData(res)).map(Country.fromJson).toList();
    await _writeList(_countriesKey, list.map((e) => e.toJson()).toList());
    return list;
  }

  Future<List<City>> cities(String countryIso) async {
    final iso = countryIso.toUpperCase();
    final key = 'lookup_cities_$iso';
    final cached = _readList(key, City.fromJson);
    if (cached.isNotEmpty) return cached;

    // the cities API is empty on the backend, so — exactly like the website —
    // cities ship as a per-country bundled asset; the API is only a fallback
    final bundled = await _bundledList('assets/data/cities/$iso.json', City.fromJson);
    if (bundled.isNotEmpty) {
      await _writeList(key, bundled.map((e) => e.toJson()).toList());
      return bundled;
    }

    final res = await _api.get('/countries/getCitiesByCountryIso/$iso');
    final list = _asList(unwrapData(res)).map(City.fromJson).toList();
    if (list.isNotEmpty) {
      await _writeList(key, list.map((e) => e.toJson()).toList());
    }
    return list;
  }

  // reads a bundled JSON array asset; returns [] if it's missing or unparsable
  Future<List<T>> _bundledList<T>(
      String assetPath, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Category>> categories() async {
    final cached = _readList('lookup_categories', Category.fromJson);
    if (cached.isNotEmpty) return cached;

    final res = await _api.get('/lookups/getAllCategories');
    final list = _asList(unwrapData(res)).map(Category.fromJson).toList();
    await _writeList('lookup_categories', list.map((e) => e.toJson()).toList());
    return list;
  }

  // public — this is what guests see on Home
  Future<List<HomeBanner>> banners() async {
    final res = await _api.get('/lookups/getHomeBanners');
    return _asList(unwrapData(res)).map(HomeBanner.fromJson).toList();
  }

  Future<void> sendContactMessage({
    required String name,
    required String email,
    required String phone,
    required String subject,
    required String message,
  }) async {
    unwrapData(await _api.post('/lookups/sendContactMessage', data: {
      'name': name,
      'email': email,
      'phone': phone,
      'subject': subject,
      'message': message,
    }));
  }

  /// Legal documents from the CMS: `{privacyPolicy, termsConditions}`,
  /// each `{title, slug, content}` (HTML). Same source the website's
  /// terms page renders. Cached — legal text rarely changes — but per
  /// language, since the API translates the content off X-Lang.
  /// [forceRefresh] is the pull-to-refresh path: skip the cache and wait
  /// for the network instead of serving yesterday's copy.
  Future<Map<String, dynamic>> pages({bool forceRefresh = false}) async {
    final key = 'lookup_pages_${LanguageService.currentCode}';
    if (!forceRefresh) {
      final cached = _cache.get<String>(key);
      if (cached != null) {
        try {
          final parsed = Map<String, dynamic>.from(jsonDecode(cached));
          _refreshPages(key).catchError((_) => parsed); // silent refresh
          return parsed;
        } catch (_) {}
      }
    }
    return _refreshPages(key);
  }

  Future<Map<String, dynamic>> _refreshPages(String key) async {
    final res = await _api.get('/lookups/getPages');
    final data = unwrapData(res);
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    await _cache.put(key, jsonEncode(map));
    return map;
  }

  /// Subscription plans (`/lookups/getAllPlans`). The web build ships with
  /// the subscription feature flagged OFF, so the app only uses this to
  /// show real plan pricing on the Increase Visibility screen.
  Future<List<Map<String, dynamic>>> plans() async {
    final res = await _api.get('/lookups/getAllPlans');
    return _asList(unwrapData(res));
  }

  /// Newsletter signup from the marketing footer.
  Future<void> addNewsletter(String email) async {
    unwrapData(await _api.post('/lookups/addNewsletter', data: {'email': email}));
  }

  /// Supported app languages for the Settings picker — [{code, name}].
  Future<List<Map<String, dynamic>>> languages() async {
    final res = await _api.get('/lookups/getLanguages');
    return _asList(unwrapData(res));
  }

  // lists sometimes come bare and sometimes wrapped in {totalRecords, list}
  List<Map<String, dynamic>> _asList(dynamic data) {
    final raw = data is Map ? (data['list'] ?? []) : (data ?? []);
    return (raw as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _cache.get<String>(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) =>
      _cache.put(key, jsonEncode(items));
}
