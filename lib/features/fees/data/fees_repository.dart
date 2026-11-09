import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:path_provider/path_provider.dart';

import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/data_bus.dart';
import 'fee_models.dart';

/// Professional transporter fee ledgers, settlement and invoices
/// (REQ §9, §10, §15 · GUIDE Screens 9, 11).
class FeesRepository {
  final _api = Get.find<ApiService>();

  Future<LedgerSummary> ledgers() async =>
      LedgerSummary.fromJson(unwrapData(await _api.get('/transporters/ledgers')));

  /// Starts paying one ledger — required (threshold reached) or voluntary.
  /// Calling it again while a settlement is open returns that same one.
  Future<Settlement> initiateSettlement(String currency) async {
    final data = unwrapData(await _api.post(
        '/transporters/ledgers/${currency.toUpperCase()}/initiate-settlement'));
    return Settlement.fromJson(
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{}, currency);
  }

  Future<List<FeeInvoice>> invoices({int page = 1}) async {
    final data = unwrapData(
        await _api.get('/transporters/invoices', queryParameters: {'page': page}));
    final rows = data is List
        ? data
        : (data is Map ? (data['list'] ?? data['invoices'] ?? data['data'] ?? const []) : const []);
    return (rows as List)
        .whereType<Map>()
        .map((e) => FeeInvoice.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// The invoice PDF: a signed URL when the API sends JSON, otherwise the PDF
  /// itself saved to a temp file. Returns `(url, file)` — exactly one is set.
  Future<(String?, File?)> downloadInvoice(FeeInvoice invoice) async {
    final res = await _api.get(
      '/transporters/invoices/${invoice.id}/download',
      options: Options(responseType: ResponseType.bytes),
    );
    final type = res.headers.value('content-type') ?? '';
    final bytes = res.data as List<int>;
    if (type.contains('json')) {
      final body = Response(requestOptions: res.requestOptions, data: _json(bytes));
      final data = unwrapData(body);
      final url = data is Map ? (data['url'] ?? data['downloadUrl'])?.toString() : '$data';
      return (url, null);
    }
    final dir = await getTemporaryDirectory();
    final name = invoice.number.isEmpty ? 'invoice_${invoice.id}' : invoice.number;
    final file = File('${dir.path}/$name.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return (null, file);
  }

  static dynamic _json(List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }

  /// After a payment: profile restrictions, wallet and deals may all change.
  static void announcePaid() {
    DataBus.changed(DataTopic.profile);
    DataBus.changed(DataTopic.wallet);
  }
}
