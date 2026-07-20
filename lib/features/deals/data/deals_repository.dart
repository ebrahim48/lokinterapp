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

  Future<List<Deal>> list(String status, {int page = 1, int limit = 100}) async {
    final res = await _api.get('/deals/getAllDeals', queryParameters: {
      'status': status,
      'limit': limit,
      'page': page,
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

  // the same endpoint also serves the user's posts, flagged POST — drop those
  List<Deal> _parse(dynamic data) {
    final rows = data is Map ? (data['list'] as List? ?? []) : const [];
    return rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['flag'] ?? 'DEAL') == 'DEAL')
        .map(Deal.fromListJson)
        .where((d) => d.id != 0)
        .toList();
  }

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

  // Traveler puts a hold on their card for the item's value before carrying it.
  // Returns whatever the escrow layer sends back (may carry a Stripe redirect).
  Future<Map<String, dynamic>> createGuarantee(int dealId) async {
    final res = await _api.post('/escrow/deals/$dealId/create-guarantee');
    final data = unwrapData(res);
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  // Throws with the server's reason when the deal can't move to OUTGOING yet.
  Future<void> checkOutgoingEligibility(int dealId) async {
    unwrapData(await _api.get('/deals/$dealId/checkOutgoingEligibility'));
  }

  Future<void> uploadPickupVideo(int dealId, String filePath, String fileName) async {
    final form = FormData.fromMap({
      'video': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    unwrapData(await _api.post('/deals/$dealId/uploadPickupVideo', data: form));
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
