import 'package:get/get.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../auth/presentation/welcome_page.dart';
import '../../data/profile_repository.dart';

class ProfileController extends GetxController {
  final session = Get.find<SessionService>();
  final summary = Rxn<RatingSummary>();
  final loggingOut = false.obs;

  final _auth = AuthRepository();
  final _repo = ProfileRepository();

  AuthUser? get user => session.user.value;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    if (session.isGuest) return;
    // both refresh quietly — the header just re-renders when they land
    try {
      await _auth.me();
    } catch (_) {}
    try {
      summary.value = await _repo.userInfo();
    } catch (_) {}
  }

  Future<void> logout() async {
    loggingOut.value = true;
    await Get.find<SocketService>().disconnect();
    await _auth.logout();
    Get.offAll(() => const WelcomePage());
  }
}
