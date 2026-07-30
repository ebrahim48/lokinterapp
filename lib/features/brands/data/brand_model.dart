import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/utils/media_url.dart';

// Partner brands are admin-managed on the backend (add/remove from the
// dashboard), so the app lists whatever `/lookups/brands` returns.
class Brand {
  final int id;
  final String name;
  final String url;
  final String? logoUrl;

  const Brand({
    this.id = 0,
    required this.name,
    required this.url,
    this.logoUrl,
  });

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
        id: json['id'] ?? 0,
        name: '${json['name'] ?? ''}',
        url: '${json['websiteUrl'] ?? json['website_url'] ?? ''}',
        logoUrl: fixMediaUrl(json['logoUrl'] ?? json['logo_url']),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'websiteUrl': url, 'logoUrl': logoUrl};

  // stable per-brand accent for the fallback initial chip
  Color get color {
    const palette = [
      Color(0xFF111111),
      Color(0xFFFF9900),
      Color(0xFFE62E04),
      Color(0xFFFB7701),
      Color(0xFF2BB673),
      Color(0xFF3480FF),
    ];
    if (name.isEmpty) return palette.first;
    return palette[name.codeUnitAt(0) % palette.length];
  }
}

class BrandsRepository {
  static const _cacheKey = 'lookup_brands';

  final _api = Get.find<ApiService>();
  final _cache = CacheService();

  /// Cached list first so the grid paints instantly, then a silent refresh.
  Future<List<Brand>> list() async {
    final cached = _cachedBrands();
    if (cached.isNotEmpty) {
      _refresh(); // fire and forget
      return cached;
    }
    return _refresh();
  }

  List<Brand> _cachedBrands() {
    final raw = _cache.get<String>(_cacheKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Brand.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Brand>> _refresh() async {
    final res = await _api.get('/lookups/brands');
    final data = unwrapData(res);
    final rows = data is Map ? (data['list'] ?? []) : (data ?? []);
    final list = (rows as List)
        .whereType<Map>()
        .map((e) => Brand.fromJson(Map<String, dynamic>.from(e)))
        .where((b) => b.name.isNotEmpty)
        .toList();
    if (list.isNotEmpty) {
      await _cache.put(_cacheKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    }
    return list;
  }
}
