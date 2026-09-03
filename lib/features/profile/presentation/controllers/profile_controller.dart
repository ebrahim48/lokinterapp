import 'dart:async';

import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/services/data_bus.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/utils/notify.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/models/auth_user.dart';
import '../../../auth/presentation/welcome_page.dart';
import '../../data/profile_repository.dart';

class ProfileController extends GetxController {
  final session = Get.find<SessionService>();
  final summary = Rxn<RatingSummary>();
  final loggingOut = false.obs;
  final deleting = false.obs;

  final _auth = AuthRepository();
  final _repo = ProfileRepository();

  AuthUser? get user => session.user.value;

  StreamSubscription<DataTopic>? _busSub;

  @override
  void onInit() {
    super.onInit();
    // a write elsewhere in the app invalidates what's on screen
    _busSub = DataBus.on({DataTopic.profile, DataTopic.deals}).listen((_) => load());
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

  // Irreversible: the backend wipes the account, so only a landed request may
  // drop the local session — a failed call leaves the user signed in as-is.
  Future<void> deleteAccount() async {
    if (deleting.value) return;
    deleting.value = true;
    try {
      await _auth.deleteAccount();
      await Get.find<SocketService>().disconnect();
      Get.offAll(() => const WelcomePage());
    } on AppException catch (e) {
      toastError(e);
    } finally {
      deleting.value = false;
    }
  }

  @override
  void onClose() {
    _busSub?.cancel();
    super.onClose();
  }
}
