import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/services/data_bus.dart';
import '../../lookups/data/lookup_models.dart';
import 'models/post_model.dart';

class PostsRepository {
  final _api = Get.find<ApiService>();
  final _cache = CacheService();

  // browse/search — searchAs TRIP|DELIVER plus whatever filters are set
  Future<Paged<Post>> search({
    required String searchAs,
    int page = 1,
    int limit = 20,
    Map<String, dynamic> filters = const {},
  }) async {
    final query = <String, dynamic>{
      'searchAs': searchAs,
      'page': page,
      'limit': limit,
      ...filters,
    }..removeWhere((_, v) => v == null);
    final res = await _api.get('/posts/getPosts', queryParameters: query);
    final paged = Paged.fromJson(unwrapData(res), Post.fromJson);
    if (page == 1 && filters.isEmpty) {
      await _cache.put('posts_$searchAs', jsonEncode(res.data['data']));
    }
    return paged;
  }

  Paged<Post>? cachedSearch(String searchAs) {
    final raw = _cache.get<String>('posts_$searchAs');
    if (raw == null) return null;
    try {
      return Paged.fromJson(jsonDecode(raw), Post.fromJson);
    } catch (_) {
      return null;
    }
  }

  Future<Post> getById(int id) async {
    final res = await _api.get('/posts/getById/$id');
    return Post.fromJson(Map<String, dynamic>.from(unwrapData(res)));
  }

  // the user's own posts — the backend serves these through the deals listing
  // as stripped-down rows flagged POST; agreements (flag DEAL) come back on the
  // same endpoint and must not show up as posts
  Future<List<Post>> myPosts(String type) async {
    final res = await _api.get('/deals/getAllDeals', queryParameters: {
      'status': type, // TRIP or DELIVER
      'limit': 100,
      'page': 1,
    });
    final data = unwrapData(res);
    final rows = data is Map ? (data['list'] as List? ?? []) : const [];
    return rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['flag'] ?? 'POST') == 'POST')
        .map(Post.fromOwnPostJson)
        .where((p) => p.id != 0)
        .toList();
  }

  Future<void> addTrip({
    required bool local,
    required Country country, // "inside" country for local, origin for intl
    Country? toCountry,
    City? fromCity,
    City? toCity,
    required DateTime date,
    String? airline,
    required double weight,
    required String pickupLocation,
    required String dropoffLocation,
    List<int> rejectedCategoryIds = const [],
  }) async {
    final form = FormData.fromMap({
      'postType': 'TRIP',
      'postLocation': local ? 'LOCAL' : 'INTERNATIONAL',
      'fromCountry': jsonEncode(country.toJson()),
      if (toCountry != null) 'toCountry': jsonEncode(toCountry.toJson()),
      if (fromCity != null) 'fromCity': jsonEncode(fromCity.toJson()),
      if (toCity != null) 'toCity': jsonEncode(toCity.toJson()),
      'beforeDate': _date(date),
      if (airline != null && airline.isNotEmpty) 'airLine': airline,
      // the API validates weight as an integer — a double serialises to "10.0"
      // in multipart and gets rejected
      'weight': weight.round(),
      // required by the backend even when empty
      'rejectedCategoriesIds': jsonEncode(rejectedCategoryIds),
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
    });
    unwrapData(await _api.post('/posts/addNewPost', data: form));
    DataBus.changed(DataTopic.posts);
  }

  Future<void> addRequest({
    required bool local,
    required bool buyAndDeliver,
    required String title,
    required Country country,
    Country? toCountry,
    City? fromCity,
    City? toCity,
    required DateTime date,
    required double weight,
    required int categoryId,
    required String pickupLocation,
    required String dropoffLocation,
    String? description,
    String? attachFilePath,
  }) async {
    final form = FormData.fromMap({
      'postType': 'DELIVER',
      'postLocation': local ? 'LOCAL' : 'INTERNATIONAL',
      'wantTo': buyAndDeliver ? 'BUY_AND_DELIVER' : 'SEND',
      'title': title,
      'fromCountry': jsonEncode(country.toJson()),
      if (toCountry != null) 'toCountry': jsonEncode(toCountry.toJson()),
      if (fromCity != null) 'fromCity': jsonEncode(fromCity.toJson()),
      if (toCity != null) 'toCity': jsonEncode(toCity.toJson()),
      'beforeDate': _date(date),
      // the API validates weight as an integer — a double serialises to "10.0"
      // in multipart and gets rejected
      'weight': weight.round(),
      'categoryId': categoryId,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      // the website stores the item description in `deliveryPoints` —
      // that's the field the API actually persists and returns
      if (description != null && description.isNotEmpty)
        'deliveryPoints': description,
      if (attachFilePath != null)
        'attachFile': await MultipartFile.fromFile(attachFilePath,
            filename: attachFilePath.split('/').last),
    });
    unwrapData(await _api.post('/posts/addNewPost', data: form));
    DataBus.changed(DataTopic.posts);
  }

  // same payload as addNewPost, just aimed at an existing post
  Future<void> updateTrip(
    int id, {
    required bool local,
    required Country country,
    Country? toCountry,
    City? fromCity,
    City? toCity,
    required DateTime date,
    String? airline,
    required double weight,
    required String pickupLocation,
    required String dropoffLocation,
    List<int> rejectedCategoryIds = const [],
  }) async {
    final form = FormData.fromMap({
      'postType': 'TRIP',
      'postLocation': local ? 'LOCAL' : 'INTERNATIONAL',
      'fromCountry': jsonEncode(country.toJson()),
      if (toCountry != null) 'toCountry': jsonEncode(toCountry.toJson()),
      if (fromCity != null) 'fromCity': jsonEncode(fromCity.toJson()),
      if (toCity != null) 'toCity': jsonEncode(toCity.toJson()),
      'beforeDate': _date(date),
      if (airline != null && airline.isNotEmpty) 'airLine': airline,
      // the API validates weight as an integer — a double serialises to "10.0"
      // in multipart and gets rejected
      'weight': weight.round(),
      'rejectedCategoriesIds': jsonEncode(rejectedCategoryIds),
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
    });
    unwrapData(await _api.post('/posts/updatePost/$id', data: form));
    DataBus.changed(DataTopic.posts);
  }

  Future<void> updateRequest(
    int id, {
    required bool local,
    required bool buyAndDeliver,
    required String title,
    required Country country,
    Country? toCountry,
    City? fromCity,
    City? toCity,
    required DateTime date,
    required double weight,
    required int categoryId,
    required String pickupLocation,
    required String dropoffLocation,
    String? description,
    String? attachFilePath,
  }) async {
    final form = FormData.fromMap({
      'postType': 'DELIVER',
      'postLocation': local ? 'LOCAL' : 'INTERNATIONAL',
      'wantTo': buyAndDeliver ? 'BUY_AND_DELIVER' : 'SEND',
      'title': title,
      'fromCountry': jsonEncode(country.toJson()),
      if (toCountry != null) 'toCountry': jsonEncode(toCountry.toJson()),
      if (fromCity != null) 'fromCity': jsonEncode(fromCity.toJson()),
      if (toCity != null) 'toCity': jsonEncode(toCity.toJson()),
      'beforeDate': _date(date),
      // the API validates weight as an integer — a double serialises to "10.0"
      // in multipart and gets rejected
      'weight': weight.round(),
      'categoryId': categoryId,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      if (description != null && description.isNotEmpty)
        'deliveryPoints': description,
      if (attachFilePath != null)
        'attachFile': await MultipartFile.fromFile(attachFilePath,
            filename: attachFilePath.split('/').last),
    });
    unwrapData(await _api.post('/posts/updatePost/$id', data: form));
    DataBus.changed(DataTopic.posts);
  }

  Future<void> deletePost(int id) async {
    unwrapData(await _api.delete('/posts/deletePost/$id'));
    DataBus.changed(DataTopic.posts);
  }

  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
