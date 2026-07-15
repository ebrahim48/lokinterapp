import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/services/session_service.dart';
import '../../../lookups/data/lookup_models.dart';
import '../../../lookups/data/lookups_repository.dart';
import '../../../posts/data/models/post_model.dart';
import '../../data/home_repository.dart';

class HomeFeedController extends GetxController {
  final banners = <HomeBanner>[].obs;
  final recommended = <Post>[].obs;
  final feed = <Post>[].obs;
  final loading = true.obs;
  final error = RxnString();

  final _repo = HomeRepository();
  final _lookups = LookupsRepository();
  final _session = Get.find<SessionService>();

  bool get isGuest => _session.isGuest;

  @override
  void onInit() {
    super.onInit();
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
}
