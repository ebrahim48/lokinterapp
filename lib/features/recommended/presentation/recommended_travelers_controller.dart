import 'package:get/get.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/services/connectivity_service.dart';
import '../../posts/data/models/post_model.dart';
import '../data/recommended_travelers_repository.dart';

enum RecommendedLoadState { initial, loading, loaded, error, offline }

/// Controller for the "See All – Recommended Travelers" screen.
///
/// Lifecycle:
///   onInit → paint cache instantly → refresh from network in background.
///   Follows the same state-machine used by HomeFeedController.
class RecommendedTravelersController extends GetxController {
  final travelers = <Post>[].obs;
  final state = RecommendedLoadState.initial.obs;
  final errorMessage = ''.obs;

  final _repo = RecommendedTravelersRepository();
  final _connectivity = Get.find<ConnectivityService>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    // Paint whatever is in the cache immediately so the screen feels instant.
    final cached = _repo.cached();
    if (cached != null) {
      travelers.assignAll(cached);
      state.value = RecommendedLoadState.loaded;
    } else {
      state.value = RecommendedLoadState.loading;
    }

    // Then attempt a fresh network fetch.
    final isOnline = await _connectivity.checkConnectivity();
    if (!isOnline) {
      if (travelers.isEmpty) state.value = RecommendedLoadState.offline;
      return;
    }

    try {
      final fresh = await _repo.fetch();
      travelers.assignAll(fresh);
      errorMessage.value = '';
      state.value = RecommendedLoadState.loaded;
    } on AppException catch (e) {
      if (travelers.isEmpty) {
        errorMessage.value = e.message;
        state.value = RecommendedLoadState.error;
      }
      // If cache was painted: silently swallow, the stale data is still useful.
    } catch (_) {
      if (travelers.isEmpty) {
        errorMessage.value = 'something_went_wrong'.tr;
        state.value = RecommendedLoadState.error;
      }
    }
  }

  /// Pull-to-refresh / retry button.
  @override
  Future<void> refresh() => load();
}
