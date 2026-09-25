import 'dart:convert';

import 'package:get/get.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/cache_service.dart';
import '../../posts/data/models/post_model.dart';

/// Fetches the full recommended-travelers list from the dedicated endpoint
/// `GET /api/v1/visibility/recommended-travelers` and keeps a Hive cache so
/// the screen still paints on a cold offline start.
///
/// Pattern mirrors HomeRepository — fetch → cache → fallback to cache on any
/// AppException.
class RecommendedTravelersRepository {
  static const _cacheKey = ApiConstants.cacheRecommendedTravelers;

  final _api = Get.find<ApiService>();
  final _cache = CacheService();

  // ── Cache ──────────────────────────────────────────────────────────────────

  /// Returns the last successful response that is still in Hive.
  /// Returns null when the cache is empty or corrupt.
  List<Post>? cached() {
    final raw = _cache.get<String>(_cacheKey);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => Post.fromJson(Map<String, dynamic>.from(e), recommended: true))
          .toList();
    } catch (_) {
      return null;
    }
  }

  bool hasCache() => cached() != null;

  // ── Network ────────────────────────────────────────────────────────────────

  /// Fetch recommended travelers from the API.
  ///
  /// On success the raw JSON list is persisted to Hive so the next call to
  /// [cached()] reflects the latest data.
  ///
  /// Throws an [AppException] sub-class on network / server errors (the caller
  /// decides whether to fall back to cache or show an error state).
  Future<List<Post>> fetch() async {
    final res = await _api.get(ApiConstants.recommendedTravelers);
    final data = unwrapData(res);

    // The endpoint may wrap the list in {data: [...]} or return a bare list.
    final rawList = data is List
        ? data
        : (data is Map ? (data['data'] ?? data['list'] ?? data) : []);

    final list = (rawList as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    // Persist the raw JSON so [cached()] can reconstruct the same objects.
    await _cache.put(_cacheKey, jsonEncode(list));

    return list
        .map((e) => Post.fromJson(e, recommended: true))
        .toList();
  }

  /// Convenience: try network first, silently fall back to cache.
  /// Re-throws only when both fail (no cache and network error).
  Future<List<Post>> fetchWithFallback() async {
    try {
      return await fetch();
    } on AppException {
      final c = cached();
      if (c != null) return c;
      rethrow;
    }
  }
}
