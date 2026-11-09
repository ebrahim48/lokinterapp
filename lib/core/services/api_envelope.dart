import 'package:get/get.dart' hide FormData, MultipartFile, Response;
import 'dart:convert';

import 'package:dio/dio.dart';
import '../exceptions/app_exceptions.dart';

// Every Lokinter response is { code, status, message, data }.
// Lists come as data: { totalRecords, list: [...] }.

dynamic unwrapData(Response res) {
  var body = res.data;
  // some endpoints emit a stray newline before the JSON (seen on
  // /transporters/invoices), so Dio can't decode it and hands back a String
  if (body is String && body.trim().startsWith('{')) {
    try {
      body = jsonDecode(body.trim());
    } catch (_) {}
  }
  if (body is Map<String, dynamic>) {
    if (body['status'] == true) return body['data'];
    throw ServerException(body['message'] ?? 'request_failed'.tr, res.statusCode,
        null, errorCodeOf(body));
  }
  throw ParsingException();
}

/// The machine-readable reason in an error body (QR_INVALID, LEDGER_OVERDUE,
/// DEAL_ALREADY_CONFIRMED…). The envelope's own `code` is the numeric HTTP
/// status, so a number there is not a reason code.
String? errorCodeOf(dynamic body) {
  if (body is! Map) return null;
  for (final k in ['errorCode', 'error_code', 'code']) {
    final v = body[k];
    if (v is String && v.isNotEmpty && int.tryParse(v) == null) return v;
  }
  return null;
}

class Paged<T> {
  final int totalRecords;
  final List<T> list;

  const Paged({required this.totalRecords, required this.list});

  factory Paged.fromJson(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    if (data is! Map) return const Paged(totalRecords: 0, list: []);
    final items = (data['list'] as List? ?? [])
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return Paged(totalRecords: data['totalRecords'] ?? items.length, list: items);
  }
}
