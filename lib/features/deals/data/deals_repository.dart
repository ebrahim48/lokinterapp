import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/cache_service.dart';
import 'deal_model.dart';

class DealsRepository {
  final _api = Get.find<ApiService>();
  final _cache = CacheService();

  Future<List<Deal>> list(String status) async {
    final res = await _api.get('/deals/getAllDeals', queryParameters: {
      'status': status,
      'limit': 100,
    });
    final data = unwrapData(res);
    if (status == 'ALL') await _cache.put('deals_all', jsonEncode(data));
    return _parse(data);
  }

  List<Deal>? cachedAll() {
    final raw = _cache.get<String>('deals_all');
    if (raw == null) return null;
    try {
      return _parse(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  // the same endpoint also serves the user's posts (flag: POST) — not deals
  List<Deal> _parse(dynamic data) => Paged.fromJson(data, Deal.fromJson)
      .list
      .where((d) => d.id != 0)
      .toList();

  // sender and traveler agree in chat, then one of them locks it in here
  Future<void> create({
    required int senderId,
    required int travelerId,
    required int postId,
    required String wantTo,
    required double cost,
    required double weight,
    required DateTime tripDate,
    String? receiverName,
    String? receiverPhone,
    String paymentMethod = 'COD',
  }) async {
    final form = FormData.fromMap({
      'senderId': senderId,
      'travelerId': travelerId,
      'postId': postId,
      'wantTo': wantTo,
      'cost': cost,
      'weight': weight,
      'tripDate': _ymd(tripDate),
      if (receiverName != null && receiverName.isNotEmpty) 'receiverName': receiverName,
      if (receiverPhone != null && receiverPhone.isNotEmpty) 'receiverPhone': receiverPhone,
      'paymentMethod': paymentMethod,
    });
    unwrapData(await _api.post('/deals/addNewDeal', data: form));
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Deal> getById(int id) async {
    final res = await _api.get('/deals/getById/$id');
    return Deal.fromJson(Map<String, dynamic>.from(unwrapData(res)));
  }

  Future<void> changeStatus(int id, String status, {String? reason}) async {
    unwrapData(await _api.post('/deals/changeStatus/$id', data: {
      'status': status,
      if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
    }));
  }

  // completion goes by reference, not numeric id
  Future<void> markCompleted(String referenceId) async {
    unwrapData(await _api.post('/deals/markAsCompleted/$referenceId'));
  }

  Future<void> rate(int dealId, int stars, String comment) async {
    unwrapData(await _api.post('/rates/addRate', data: {
      'dealId': dealId,
      'stars': stars,
      if (comment.isNotEmpty) 'comment': comment,
    }));
  }

  Future<Map<String, dynamic>?> disputeReport(int dealId) async {
    final res = await _api.get('/disputes/deal/$dealId');
    final data = unwrapData(res);
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }
}
