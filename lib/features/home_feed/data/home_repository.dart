import 'dart:convert';

import 'package:get/get.dart';
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/cache_service.dart';
import '../../lookups/data/lookup_models.dart';
import '../../posts/data/models/post_model.dart';

class HomeData {
  final List<HomeBanner> banners;
  final List<Post> recommended;
  final List<Post> latestDeals;

  const HomeData({
    this.banners = const [],
    this.recommended = const [],
    this.latestDeals = const [],
  });

  factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
        banners: _items(json['banners']).map(HomeBanner.fromJson).toList(),
        recommended: _items(json['recommendedTravelers'])
            .map((e) => Post.fromJson(e, recommended: true))
            .toList(),
        latestDeals: _items(json['latestDeals']).map(Post.fromJson).toList(),
      );

  static List<Map<String, dynamic>> _items(dynamic raw) => (raw as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

// One aggregated call feeds the whole Home screen. The raw payload is kept
// in Hive so a cold offline start still paints the last known feed.
class HomeRepository {
  static const _cacheKey = 'home_mobile';

  final _api = Get.find<ApiService>();
  final _cache = CacheService();

  HomeData? cached() {
    final raw = _cache.get<String>(_cacheKey);
    if (raw == null) return null;
    try {
      return HomeData.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<HomeData> fetch() async {
    final res = await _api.get('/home/mobile');
    final data = Map<String, dynamic>.from(unwrapData(res));
    await _cache.put(_cacheKey, jsonEncode(data));
    return HomeData.fromJson(data);
  }
}
