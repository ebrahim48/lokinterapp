import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_task/core/services/session_service.dart';
import 'package:flutter_task/core/services/storage_service.dart';
import 'package:flutter_task/main.dart' as app;

const phase = String.fromEnvironment('PHASE', defaultValue: 'login');

Future<void> pumpUntil(WidgetTester t, Finder f, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 4; i++) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('timed out waiting for $f');
}

Future<void> settle(WidgetTester t, [int ms = 3000]) async {
  for (var i = 0; i < ms ~/ 250; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real flow: $phase', (t) async {
    await app.main();
    await settle(t, 4000);
    final shot = binding.takeScreenshot;
    await binding.convertFlutterSurfaceToImage();
    await t.pump();

    if (phase == 'login') {
      // start clean so the login is real
      if (Get.find<SessionService>().loggedIn) {
        await Get.find<SessionService>().clear();
        Get.offAllNamed('/');
      }
      await pumpUntil(t, find.text('welcome.login'.tr));
      await t.tap(find.text('welcome.login'.tr));
      await settle(t, 1500);
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'test@gmail.com');
      await t.enterText(fields.at(1), '12345678');
      await t.tap(find.text('login'.tr).last);
      await pumpUntil(t, find.text('nav.deals'.tr));
      await settle(t, 6000);
      await shot('01_home_after_login');

      final s = Get.find<SessionService>();
      expect(s.loggedIn, isTrue);
      const secure = FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true));
      final inKeychain = await secure.read(key: StorageKeys.authToken);
      final inPrefs = Get.find<StorageService>().getString(StorageKeys.authToken);
      debugPrint('REAL keychain token present: ${inKeychain != null}, '
          'prefs token present: ${inPrefs != null}');
      expect(inKeychain, s.accessToken);
      expect(inPrefs, isNull);

      // deals: sender's rejected deal shows the remaining attempt counter
      await t.tap(find.text('nav.deals'.tr));
      await settle(t, 5000);
      await shot('02_deals');
      final maxed = find.text('maximum_attempts_reached'.tr);
      await t.scrollUntilVisible(maxed, 400,
          scrollable: find.byType(Scrollable).last, maxScrolls: 60);
      await settle(t, 800);
      await shot('03_deals_attempts_badge');
      debugPrint('REAL attempts badges: max=${maxed.evaluate().length}, '
          'two=${find.text('attempts_remaining'.trParams({'n': '2'})).evaluate().length}');

      // profile → my posts (expired/consumed hidden) and basic info
      await t.tap(find.text('nav.profile'.tr));
      await settle(t, 3000);
      await t.tap(find.text('my_requests_and_trips'.tr).first);
      await settle(t, 5000);
      await shot('04_my_posts');
      await t.pageBack();
      await settle(t, 1500);
      await t.tap(find.text('basic_info'.tr));
      await settle(t, 5000);
      await shot('05_basic_info');
      debugPrint('REAL country label: '
          '${find.text('country_of_residence'.tr).evaluate().length}');
    } else {
      // relaunch: no login, the saved session must land straight in the shell
      await pumpUntil(t, find.text('nav.deals'.tr), seconds: 20);
      await settle(t, 5000);
      await shot('06_relaunch_still_logged_in');
      expect(Get.find<SessionService>().loggedIn, isTrue);
      expect(find.text('welcome.login'.tr), findsNothing);
      debugPrint('REAL relaunch logged in: true');
    }
  });
}
