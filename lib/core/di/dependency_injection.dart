import 'package:get/get.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/language_service.dart';
import '../services/push_service.dart';
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

    // language is restored from local storage before the first frame
    Get.put<LanguageService>(LanguageService(storage).restore(), permanent: true);

    // restore any saved login before the first screen decides where to go
    final session = SessionService(storage).restore();
    Get.put<SessionService>(session, permanent: true);
    Get.put<SocketService>(SocketService(session), permanent: true);

    // Firebase + the FCM listeners come up here so a push that cold-started the
    // app is already waiting when the first screen asks for it. The permission
    // prompt and the token itself wait for PushService.start() (MainShell).
    // Registered before init() so the rest of the app can always find it —
    // init() leaves the service inert when Firebase can't come up, but a
    // half-registered service would crash MainShell's Get.find outright.
    final push = Get.put<PushService>(PushService(session, storage), permanent: true);
    await push.init();
  }

  static void clear() => Get.deleteAll(force: true);
}
