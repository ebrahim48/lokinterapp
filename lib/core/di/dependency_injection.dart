import 'package:get/get.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/storage_service.dart';

// Wires up the core infrastructure (HTTP, cache, connectivity, storage).
// Feature repositories/controllers get registered here as the API layer lands.
class DependencyInjection {
  DependencyInjection._();

  static Future<void> init() async {
    Get.lazyPut<CacheService>(() => CacheService(), fenix: true);
    Get.lazyPut<ApiService>(() => ApiService(), fenix: true);
    Get.lazyPut<ConnectivityService>(() => ConnectivityService(), fenix: true);

    // eager — SharedPreferences.getInstance() is async
    final storage = StorageService();
    await storage.init();
    Get.put<StorageService>(storage, permanent: true);
  }

  static void clear() => Get.deleteAll(force: true);
}
