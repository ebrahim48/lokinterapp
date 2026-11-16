// GUIDE Screen 1 §5: trips and delivery requests carry exact map pins
// (pickupLat/Lng, dropoffLat/Lng) next to the required address strings.
// Pins are optional and only sent when picked; the post model reads them back
// in camelCase or snake_case so editing a post keeps its pins.
import 'package:dio/dio.dart';
import 'package:flutter_task/core/services/api_service.dart';
import 'package:flutter_task/core/widgets/location_picker_page.dart';
import 'package:flutter_task/features/lookups/data/lookup_models.dart';
import 'package:flutter_task/features/posts/data/models/post_model.dart';
import 'package:flutter_task/features/posts/data/posts_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide FormData, Response;

/// Captures the multipart body instead of hitting the network.
class _FakeApi implements ApiService {
  final sent = <String, Map<String, String>>{};

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    sent[path] = {for (final e in (data as FormData).fields) e.key: e.value};
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: {
        'status': true,
        'data': {'id': 42},
      },
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _tn = Country(id: 83, name: 'Tunisia', iso2: 'TN');
const _tunis = City(id: 1, name: 'Tunis');
const _sousse = City(id: 2, name: 'Sousse');

void main() {
  late _FakeApi api;
  late PostsRepository repo;

  setUp(() {
    Get.reset();
    api = _FakeApi();
    Get.put<ApiService>(api);
    repo = PostsRepository();
  });

  group('delivery request', () {
    test('local request sends the address and all four coordinates', () async {
      final id = await repo.addRequest(
        local: true,
        buyAndDeliver: false,
        title: 'Shoes',
        country: _tn,
        toCountry: _tn,
        fromCity: _tunis,
        toCity: _sousse,
        date: DateTime(2026, 8, 1),
        weight: 5,
        categoryIds: [3],
        pickupLocation: 'Tunis Central',
        dropoffLocation: 'Sousse Central',
        pickupLat: 36.8065,
        pickupLng: 10.1815,
        dropoffLat: 35.8256,
        dropoffLng: 10.63699,
      );
      expect(id, 42);
      final f = api.sent['/posts/addNewPost']!;
      expect(f['postType'], 'DELIVER');
      expect(f['postLocation'], 'LOCAL');
      expect(f['pickupLocation'], 'Tunis Central');
      expect(f['pickupLat'], '36.8065');
      expect(f['pickupLng'], '10.1815');
      expect(f['dropoffLocation'], 'Sousse Central');
      expect(f['dropoffLat'], '35.8256');
      expect(f['dropoffLng'], '10.63699');
    });

    test('no pin picked: address only, never a guessed coordinate', () async {
      await repo.addRequest(
        local: false,
        buyAndDeliver: false,
        title: 'Shoes',
        country: _tn,
        date: DateTime(2026, 8, 1),
        weight: 5,
        categoryIds: [3],
        pickupLocation: '',
        dropoffLocation: '',
      );
      final f = api.sent['/posts/addNewPost']!;
      expect(f['pickupLocation'], '-'); // API still requires the string
      expect(f['dropoffLocation'], '-');
      for (final k in ['pickupLat', 'pickupLng', 'dropoffLat', 'dropoffLng']) {
        expect(f.containsKey(k), isFalse, reason: k);
      }
    });

    test('update sends the pins too', () async {
      await repo.updateRequest(
        7,
        local: true,
        buyAndDeliver: false,
        title: 'Shoes',
        country: _tn,
        toCountry: _tn,
        date: DateTime(2026, 8, 1),
        weight: 5,
        categoryIds: [3],
        pickupLocation: 'Tunis Central',
        dropoffLocation: 'Sousse Central',
        pickupLat: 36.8065,
        pickupLng: 10.1815,
        dropoffLat: 35.8256,
        dropoffLng: 10.63699,
      );
      final f = api.sent['/posts/updatePost/7']!;
      expect(f['pickupLat'], '36.8065');
      expect(f['dropoffLng'], '10.63699');
    });
  });

  group('trip', () {
    test('local trip with pins sends them', () async {
      await repo.addTrip(
        local: true,
        country: _tn,
        toCountry: _tn,
        fromCity: _tunis,
        toCity: _sousse,
        date: DateTime(2026, 8, 1),
        weight: 10,
        pickupLocation: 'Tunis Central',
        dropoffLocation: 'Sousse Central',
        pickupLat: 36.8065,
        pickupLng: 10.1815,
        dropoffLat: 35.8256,
        dropoffLng: 10.63699,
        rejectedCategoryIds: [3, 4],
      );
      final f = api.sent['/posts/addNewPost']!;
      expect(f['postType'], 'TRIP');
      expect(f['rejectedCategoriesIds'], '[3,4]');
      expect(f['pickupLocation'], 'Tunis Central');
      expect(f['pickupLat'], '36.8065');
      expect(f['dropoffLat'], '35.8256');
    });

    test('trip without pins keeps the old placeholder payload', () async {
      await repo.updateTrip(
        9,
        local: false,
        country: _tn,
        date: DateTime(2026, 8, 1),
        weight: 10,
        pickupLocation: '',
        dropoffLocation: '',
      );
      final f = api.sent['/posts/updatePost/9']!;
      expect(f['pickupLocation'], '-');
      expect(f['dropoffLocation'], '-');
      expect(f.keys.where((k) => k.endsWith('Lat') || k.endsWith('Lng')), isEmpty);
    });

    test('a half pin (lat without lng) is not sent', () async {
      await repo.addTrip(
        local: true,
        country: _tn,
        date: DateTime(2026, 8, 1),
        weight: 10,
        pickupLocation: 'Tunis Central',
        dropoffLocation: '',
        pickupLat: 36.8065,
      );
      final f = api.sent['/posts/addNewPost']!;
      expect(f.containsKey('pickupLat'), isFalse);
    });
  });

  group('post model', () {
    Map<String, dynamic> row(Map<String, dynamic> extra) => {
          'id': 1,
          'type': 'DELIVER',
          'location': 'LOCAL',
          'fromCountry': {'name': 'Tunisia', 'iso2': 'TN'},
          'toCountry': {'name': 'Tunisia', 'iso2': 'TN'},
          'beforeDate': '2026-08-01',
          'weight': '5',
          'user': {'id': 3, 'name': 'A'},
          ...extra,
        };

    test('reads camelCase pins (numbers or strings)', () {
      final p = Post.fromJson(row({
        'pickupLocation': 'Tunis Central',
        'pickupLat': 36.8065,
        'pickupLng': '10.1815',
        'dropoffLat': '35.8256',
        'dropoffLng': 10.63699,
      }));
      expect(p.pickupLat, 36.8065);
      expect(p.pickupLng, 10.1815);
      expect(p.dropoffLat, 35.8256);
      expect(p.dropoffLng, 10.63699);
    });

    test('reads snake_case pins', () {
      final p = Post.fromJson(row({'pickup_lat': '36.8', 'pickup_lng': 10.1}));
      expect(p.pickupLat, 36.8);
      expect(p.pickupLng, 10.1);
    });

    test('missing pins stay null, never 0,0', () {
      final p = Post.fromJson(row({'pickupLocation': 'Tunis Central'}));
      expect(p.pickupLat, isNull);
      expect(p.dropoffLng, isNull);
    });

    test('own-post rows read pins too', () {
      final p = Post.fromOwnPostJson({
        'id': 1,
        'status': 'DELIVER',
        'location': 'LOCAL',
        'pickupLat': 36.8065,
        'pickupLng': 10.1815,
      });
      expect(p.pickupLat, 36.8065);
      expect(p.pickupLng, 10.1815);
    });
  });

  group('edit prefill helpers', () {
    test('placeFrom only builds a pin from real coordinates', () {
      expect(placeFrom('Tunis Central', null, 10.18), isNull);
      final pin = placeFrom('Tunis Central', 36.8065, 10.1815)!;
      expect(pin.label, 'Tunis Central');
      expect(pin.lat, 36.8065);
    });

    test('a pin saved without an address is labelled by its coordinates', () {
      expect(placeFrom('-', 36.8065, 10.1815)!.label, '36.80650, 10.18150');
    });

    test('the "-" placeholder is not shown as an address', () {
      expect(realAddress('-'), '');
      expect(realAddress(' Tunis '), 'Tunis');
      expect(realAddress(null), '');
    });
  });
}
