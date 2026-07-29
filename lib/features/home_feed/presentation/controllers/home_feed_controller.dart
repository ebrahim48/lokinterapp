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
      _apply(await _repo.fetch());
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
    final results = await Future.wait([
      _posts.search(searchAs: 'DELIVER', limit: 20).then((p) => p.list).catchError((_) => <Post>[]),
      _posts.search(searchAs: 'TRIP', limit: 20).then((p) => p.list).catchError((_) => <Post>[]),
    ]);
    requests.assignAll(results[0]);
    trips.assignAll(results[1]);
    if (requests.isNotEmpty || trips.isNotEmpty) error.value = null;
  }

  // guests only get the public banners — the rest of Home asks them to log in
  Future<void> _loadGuest() async {
    try {
      banners.assignAll(await _lookups.banners());
    } catch (_) {}
    loading.value = false;
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
