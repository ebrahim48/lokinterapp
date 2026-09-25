import 'dart:async';

import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/services/data_bus.dart';
import '../../../../core/services/session_service.dart';
import '../../../lookups/data/lookup_models.dart';
import '../../../lookups/data/lookups_repository.dart';
import '../../../posts/data/models/post_model.dart';
import '../../../posts/data/posts_repository.dart';
import '../../data/home_repository.dart';

class HomeFeedController extends GetxController {
  final banners = <HomeBanner>[].obs;
  final recommended = <Post>[].obs;
  final feed = <Post>[].obs;
  final loading = true.obs;
  final error = RxnString();

  // trips and requests are listed together; the filter only narrows the view
  final requests = <Post>[].obs;
  final trips = <Post>[].obs;
  final filter = 'ALL'.obs; // ALL | DELIVER | TRIP

  final _repo = HomeRepository();
  final _posts = PostsRepository();
  final _lookups = LookupsRepository();
  final _session = Get.find<SessionService>();

  // newest first, so a fresh trip and a fresh request interleave naturally
  List<Post> get visibleFeed {
    final list = switch (filter.value) {
      'DELIVER' => requests.toList(),
      'TRIP' => trips.toList(),
      _ => [...requests, ...trips],
    };
    list.sort((a, b) => b.id.compareTo(a.id));
    return list.isEmpty && filter.value == 'ALL' ? feed.toList() : list;
  }

  bool get isGuest => _session.isGuest;

  /// ISO2 of the logged-in user's country — used to filter recommended results.
  String? get _userCountry => _session.user.value?.country;

  StreamSubscription<DataTopic>? _busSub;

  @override
  void onInit() {
    super.onInit();
    // a write elsewhere in the app invalidates what's on screen
    // reload on writes and on a language switch (CMS content is server-localized)
    _busSub =
        DataBus.on({DataTopic.posts, DataTopic.deals, DataTopic.language}).listen((_) => load());
    load();
  }

  Future<void> load() async {
    if (isGuest) return _loadGuest();

    // paint the cached feed instantly, then refresh from the network
    final cached = _repo.cached();
    if (cached != null) {
      _apply(cached);
      loading.value = false;
    }
    try {
      // Pass user country so the backend filters recommended
      // travelers/transporters to routes relevant to that country (req 1.6).
      _apply(await _repo.fetch(userCountry: _userCountry));
      error.value = null;
    } on AppException catch (e) {
      if (recommended.isEmpty && feed.isEmpty) error.value = e.message;
    } finally {
      loading.value = false;
    }
    await _loadPosts();
  }

  // home lists everything that's been posted — both sides of the marketplace
  Future<void> _loadPosts() async {
    final country = _userCountry;
    // Pass country in filters so the backend can return country-relevant posts
    // (requirement 1.6 — country-based recommendations).
    final countryFilter = (country != null && country.isNotEmpty)
        ? <String, dynamic>{'country': country}
        : const <String, dynamic>{};

    final results = await Future.wait([
      _posts
          .search(searchAs: 'DELIVER', limit: 20, filters: countryFilter)
          .then((p) => p.list)
          .catchError((_) => <Post>[]),
      _posts
          .search(searchAs: 'TRIP', limit: 20, filters: countryFilter)
          .then((p) => p.list)
          .catchError((_) => <Post>[]),
    ]);
    requests.assignAll(results[0]);
    trips.assignAll(results[1]);
    if (requests.isNotEmpty || trips.isNotEmpty) error.value = null;
  }

  // guests still browse what everyone posted — they're only asked to log in
  // when they try to act on it (chat, deal, post)
  Future<void> _loadGuest() async {
    try {
      banners.assignAll(await _lookups.banners());
    } catch (_) {}
    await _loadGuestPosts();
    loading.value = false;
  }

  Future<void> _loadGuestPosts() async {
    final results = await Future.wait([
      _posts.search(searchAs: 'DELIVER', limit: 20).then((p) => p.list).catchError((_) => <Post>[]),
      _posts.search(searchAs: 'TRIP', limit: 20).then((p) => p.list).catchError((_) => <Post>[]),
    ]);
    requests.assignAll(results[0]);
    trips.assignAll(results[1]);
  }

  void _apply(HomeData data) {
    banners.assignAll(data.banners);
    recommended.assignAll(data.recommended);
    feed.assignAll(data.latestDeals);
  }

  @override
  void onClose() {
    _busSub?.cancel();
    super.onClose();
  }
}
