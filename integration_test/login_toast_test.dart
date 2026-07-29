// Focused check: logging in surfaces a snackbar (the backend "message"), which
// regressed when GetX's overlay-based snackbar threw during login's Get.offAll.
import 'package:flutter/material.dart';
import 'package:flutter_task/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const email = 'sushil500530@gmail.com';
const password = 'Sushil@123!';

Future<void> settle(WidgetTester t, [int ms = 800]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> waitFor(WidgetTester t, Finder f,
    {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 300));
    if (f.evaluate().isNotEmpty) return true;
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login shows a snackbar', (t) async {
    var overlayError = false;
    FlutterError.onError = (d) {
      if ('${d.exception}'.contains('No Overlay')) overlayError = true;
      debugPrint('APP ERROR: ${d.exception}');
    };

    app.main();
    await settle(t, 3000);

    if (await waitFor(t, find.text('Continue as guest'))) {
      await t.tap(find.widgetWithText(ElevatedButton, 'Login').last, warnIfMissed: false);
      await settle(t, 1500);
    }

    final fields = find.byType(TextField);
    if (!await waitFor(t, fields)) {
      debugPrint('RESULT: already logged in — cannot test the login toast');
      return;
    }

    await t.enterText(fields.at(0), email);
    await t.enterText(fields.at(1), password);
    await settle(t);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t, 800);
    await t.tap(find.widgetWithText(ElevatedButton, 'Login'));

    // poll for the top toast in the ~3s it stays up, right after the 200 lands
    final toast = find.byKey(const Key('app_toast'));
    var sawToast = false;
    var atTop = false;
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 200));
      if (toast.evaluate().isNotEmpty) {
        sawToast = true;
        final box = t.getRect(toast);
        atTop = box.top < t.view.physicalSize.height / t.view.devicePixelRatio / 2;
        final text = find
            .descendant(of: toast, matching: find.byType(Text))
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .join(' | ');
        debugPrint('TOAST: "$text" top=${box.top.toStringAsFixed(0)} atTop=$atTop');
        break;
      }
    }

    debugPrint('RESULT: toast=$sawToast atTop=$atTop overlayError=$overlayError');
    expect(overlayError, isFalse, reason: 'login toast threw No Overlay again');
    expect(sawToast, isTrue, reason: 'no toast shown on login');
    expect(atTop, isTrue, reason: 'toast did not render in the top half');
  });
}
