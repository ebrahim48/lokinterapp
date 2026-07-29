import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/services/session_service.dart';
import '../../../lookups/data/lookup_models.dart';
import '../../../lookups/data/lookups_repository.dart';
import '../../../posts/data/models/post_model.dart';
import '../../../posts/data/posts_repository.dart';

class SearchResultsController extends GetxController {
  // 0 = Trips, 1 = Requests
  final tab = 0.obs;
  final results = <Post>[].obs;
  final loading = true.obs;
  final loadingMore = false.obs;
  final error = RxnString();

  // filter sheet state
  final countries = <Country>[].obs;
  final cities = <City>[].obs;
  final filters = <String, dynamic>{};

  int _page = 1;
  bool _hasMore = true;

  final _repo = PostsRepository();
  final _lookups = LookupsRepository();

  bool get isGuest => Get.find<SessionService>().isGuest;
  String get _searchAs => tab.value == 0 ? 'TRIP' : 'DELIVER';

  @override
  void onInit() {
    super.onInit();
    // int = just the tab; Map = tab + prebuilt filters from the home search form
    final args = Get.arguments;
    if (args is int) {
      tab.value = args;
    } else if (args is Map) {
      if (args['tab'] is int) tab.value = args['tab'] as int;
      if (args['filters'] is Map) {
        filters.addAll(Map<String, dynamic>.from(args['filters'] as Map));
      }
    }
    ever(tab, (_) => load());
    _lookups.countries().then(countries.assignAll).catchError((_) {});
    load();
  }

  Future<void> load() async {
    if (isGuest) {
      loading.value = false;
      return;
    }
    _page = 1;
    _hasMore = true;

    // instant paint from the last unfiltered fetch of this tab
    if (filters.isEmpty) {
      final cached = _repo.cachedSearch(_searchAs);
      if (cached != null && cached.list.isNotEmpty) {
        results.assignAll(cached.list);
        loading.value = false;
      } else {
        loading.value = true;
      }
    } else {
      loading.value = true;
    }

    try {
      final paged = await _repo.search(searchAs: _searchAs, filters: filters);
      results.assignAll(paged.list);
      _hasMore = paged.list.length < paged.totalRecords;
      error.value = null;
    } on AppException catch (e) {
      if (results.isEmpty) error.value = e.message;
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || loadingMore.value || loading.value) return;
    loadingMore.value = true;
    try {
      final paged =
          await _repo.search(searchAs: _searchAs, page: ++_page, filters: filters);
      results.addAll(paged.list);
      _hasMore = results.length < paged.totalRecords && paged.list.isNotEmpty;
    } on AppException catch (_) {
      _page--;
    } finally {
      loadingMore.value = false;
    }
  }

  Future<void> loadCities(Country country) async {
    cities.clear();
    try {
      cities.assignAll(await _lookups.cities(country.iso2));
    } catch (_) {}
  }

  void applyFilters(Map<String, dynamic> next) {
    filters
      ..clear()
      ..addAll(next);
    load();
  }
}
