import 'package:get/get.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/session_service.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';

// Wires up the core infrastructure (HTTP, cache, connectivity, storage).
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

    // restore any saved login before the first screen decides where to go
    final session = SessionService(storage).restore();
    Get.put<SessionService>(session, permanent: true);
    Get.put<SocketService>(SocketService(session), permanent: true);
  }

  static void clear() => Get.deleteAll(force: true);
}
