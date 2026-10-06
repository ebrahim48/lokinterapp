import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/services/data_bus.dart';
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
    final deals = _parse(data);
    if (status != DealStatus.disputes.apiValue) return deals;

    // a deal disputed after completion can keep status COMPLETED server-side;
    // it still belongs under Disputed Deals while the dispute is open
    try {
      final all = await list('ALL', limit: limit);
      final ids = deals.map((d) => d.id).toSet();
      return [
        ...deals,
        ...all.where((d) => d.hasOpenDispute && !ids.contains(d.id)),
      ];
    } on AppException catch (_) {
      return deals;
    }
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

  // sender and traveler agree in chat, then one of them locks it in here.
  // itemEstimatedCost / arrivalDate / sdRequired are part of the escrow terms
  // and the endpoint expects them alongside the basics. Website parity:
  // itemName is required for BUY_AND_DELIVER, itemLink/itemDescription are
  // optional context, attachFiles carry item photos.
  Future<void> create({
    required int senderId,
    required int travelerId,
    required int postId,
    required String wantTo,
    required double cost,
    required double itemEstimatedCost,
    required double weight,
    required DateTime tripDate,
    required DateTime arrivalDate,
    required bool sdRequired,
    String? itemName,
    String? itemLink,
    String? itemDescription,
    String? receiverName,
    String? receiverPhone,
    List<String> attachFilePaths = const [],
    String paymentMethod = 'COD',
  }) async {
    final form = FormData.fromMap({
      'senderId': senderId,
      'travelerId': travelerId,
      'postId': postId,
      'wantTo': wantTo,
      // the API validates cost as an integer, same as weight
      'cost': cost.round(),
      'itemEstimatedCost': itemEstimatedCost,
      // same as posts: a double serialises to "10.0" and fails integer validation
      'weight': weight.round(),
      'tripDate': _ymd(tripDate),
      'arrivalDate': _ymd(arrivalDate),
      'sdRequired': sdRequired ? 1 : 0,
      if (itemName != null && itemName.isNotEmpty) 'itemName': itemName,
      if (itemLink != null && itemLink.isNotEmpty) 'itemLink': itemLink,
      if (itemDescription != null && itemDescription.isNotEmpty)
        'itemDescription': itemDescription,
      if (receiverName != null && receiverName.isNotEmpty) 'receiverName': receiverName,
      if (receiverPhone != null && receiverPhone.isNotEmpty) 'receiverPhone': receiverPhone,
      'paymentMethod': paymentMethod,
    });
    for (final path in attachFilePaths) {
      form.files.add(MapEntry(
        'attachFiles[]',
        await MultipartFile.fromFile(path, filename: path.split('/').last),
      ));
    }
    unwrapData(await _api.post('/deals/addNewDeal', data: form));
    DataBus.changed(DataTopic.deals);
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Deal> getById(int id) async {
    final res = await _api.get('/deals/getById/$id');
    return Deal.fromJson(Map<String, dynamic>.from(unwrapData(res)));
  }

  // the QR encodes /deal-details/{referenceId}; this resolves that code back
  // to a deal (same endpoint the website's public confirmation page hits)
  Future<Deal> getByReferenceId(String referenceId) async {
    final res = await _api.get('/deals/getByReferenceId/$referenceId');
    return Deal.fromJson(Map<String, dynamic>.from(unwrapData(res)));
  }

  Future<void> changeStatus(int id, String status, {String? reason}) async {
    unwrapData(await _api.post('/deals/changeStatus/$id', data: {
      'status': status,
      if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
    }));
    DataBus.changed(DataTopic.deals);
  }

  // Traveler puts a hold on their card for the item's value before carrying it.
  // Returns `{clientSecret, paymentIntentId}` for the in-app Stripe confirm.
  Future<Map<String, dynamic>> createGuarantee(int dealId) async {
    final res = await _api.post('/escrow/deals/$dealId/create-guarantee');
    final data = unwrapData(res);
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  // Sender pays into escrow; funds are held until delivery is confirmed.
  // Returns `{clientSecret, paymentIntentId, breakdown{itemCost, profit,
  // lokinterFee, total}}` for the in-app Stripe confirm + fee display.
  Future<Map<String, dynamic>> createPayment(int dealId) async {
    final res = await _api.post('/escrow/deals/$dealId/create-payment');
    final data = unwrapData(res);
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  // After Stripe confirms the card, tell the backend so it flips the
  // held flags and posts the escrow system message — same two-step the
  // website does (confirmCardPayment → escrow/confirm-*).
  Future<void> confirmPayment(int dealId, String paymentIntentId) async {
    unwrapData(await _api.post('/escrow/deals/$dealId/confirm-payment',
        data: {'paymentIntentId': paymentIntentId}));
    DataBus.changed(DataTopic.deals);
  }

  Future<void> confirmGuarantee(int dealId, String paymentIntentId) async {
    unwrapData(await _api.post('/escrow/deals/$dealId/confirm-guarantee',
        data: {'paymentIntentId': paymentIntentId}));
    DataBus.changed(DataTopic.deals);
  }

  // Throws with the server's reason when the deal can't move to OUTGOING yet.
  Future<void> checkOutgoingEligibility(int dealId) async {
    unwrapData(await _api.get('/deals/$dealId/checkOutgoingEligibility'));
  }

  Future<void> uploadPickupVideo(
    int dealId,
    String filePath,
    String fileName, {
    void Function(int sent, int total)? onProgress,
    Duration timeout = const Duration(seconds: 300),
  }) async {
    final form = FormData.fromMap({
      'video': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    unwrapData(await _api.post(
      '/deals/$dealId/uploadPickupVideo',
      data: form,
      onSendProgress: onProgress,
      options: Options(receiveTimeout: timeout, sendTimeout: timeout),
    ));
    DataBus.changed(DataTopic.deals);
  }

  /// Delivery proof, posted against the reference the QR encodes. The endpoint
  /// is unauthenticated by design — it's the receiver's handover, reached from
  /// the QR — so the traveler can complete it in the app after scanning.
  Future<void> uploadDeliveryVideo(
    String referenceId,
    String filePath,
    String fileName, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'video': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    unwrapData(await _api.post('/deals/$referenceId/uploadDeliveryVideo',
        data: form, onSendProgress: onProgress));
    DataBus.changed(DataTopic.deals);
  }

  // completion goes by reference, not numeric id
  /// [completionType]: QR_SCAN (traveler scanned the receiver's code) or
  /// SENDER_CONFIRMATION (sender marked it delivered).
  Future<void> markCompleted(String referenceId, {String? completionType}) async {
    unwrapData(await _api.post('/deals/markAsCompleted/$referenceId',
        data: {if (completionType != null) 'completion_type': completionType}));
    DataBus.changed(DataTopic.deals);
  }

  Future<void> rate(int dealId, int stars, String comment) async {
    unwrapData(await _api.post('/rates/addRate', data: {
      'dealId': dealId,
      'stars': stars,
      if (comment.isNotEmpty) 'comment': comment,
    }));
  }

  /// Live FX for the deal form. The backend owns the rate source and caches it
  /// for an hour, so no key or rate logic ships in the app.
  /// Returns `{from, to, amount, rate, convertedAmount}`.
  Future<Map<String, dynamic>> convertCurrency({
    required String from,
    required String to,
    required double amount,
  }) async {
    final res = await _api.get('/currency/convert', queryParameters: {
      'from': from,
      'to': to,
      'amount': amount,
    });
    final data = unwrapData(res);
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> disputeReport(int dealId) async {
    final res = await _api.get('/disputes/deal/$dealId');
    final data = unwrapData(res);
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  // ---- dispute creation (website: open-dispute dialog in chat/deal) ----

  /// Contextual reasons for this deal's state — e.g. ghosting reasons are
  /// only offered while OUTGOING. Each entry: `{value, label}`-ish map.
  Future<List<Map<String, dynamic>>> disputeReasons(int dealId) async {
    final res = await _api
        .get('/disputes/reasons', queryParameters: {'deal_id': dealId});
    final data = unwrapData(res);
    final list = data is List ? data : (data is Map ? data['reasons'] : null);
    return (list as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Dispute window info: `{canDispute, remainingSeconds, windowHours...}`.
  Future<Map<String, dynamic>> disputeWindow(int dealId) async {
    final res = await _api.get('/disputes/deal/$dealId/window');
    final data = unwrapData(res);
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// ITEM_DAMAGED / WRONG_ITEM require photo/video evidence — enforced
  /// server-side, mirrored in the sheet before calling this.
  /// Every picked file goes up as `proof_files[]` on createDispute — the
  /// endpoint that stores all of them (the older /disputes/deal/{id} route
  /// kept only one, so the admin saw a single image).
  Future<void> createDispute(
    int dealId, {
    required String reason,
    String? description,
    List<String> attachmentPaths = const [],
    String? attachmentPath,
  }) async {
    final allPaths = [
      ...attachmentPaths,
      if (attachmentPath != null && !attachmentPaths.contains(attachmentPath))
        attachmentPath,
    ];

    final form = FormData.fromMap({
      'deal_id': dealId,
      'reason': reason,
      if (description != null && description.isNotEmpty) 'description': description,
    });

    for (final path in allPaths) {
      form.files.add(MapEntry(
        'proof_files[]',
        await MultipartFile.fromFile(path, filename: path.split('/').last),
      ));
    }

    unwrapData(await _api.post('/disputes/createDispute/$dealId', data: form));
    DataBus.changed(DataTopic.deals);
  }
}
