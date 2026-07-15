import 'package:dio/dio.dart';
import '../exceptions/app_exceptions.dart';

// Every Lokinter response is { code, status, message, data }.
// Lists come as data: { totalRecords, list: [...] }.

dynamic unwrapData(Response res) {
  final body = res.data;
  if (body is Map<String, dynamic>) {
    if (body['status'] == true) return body['data'];
    throw ServerException(body['message'] ?? 'Request failed', res.statusCode);
  }
  throw ParsingException('Unexpected response body');
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
