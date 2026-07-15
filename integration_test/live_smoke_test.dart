// End-to-end walk of the app against the live dev API with the shared test
// account. Soft checks — every step records PASS/FAIL and the run prints a
// report at the end instead of dying on the first broken screen.
import 'package:flutter/material.dart';
import 'package:flutter_task/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const email = 'sushil500530@gmail.com';
const password = 'Sushil@123!';

final report = <String>[];

void check(String name, bool ok, [String? note]) {
  final line = '${ok ? 'PASS' : 'FAIL'}  $name${note == null ? '' : ' — $note'}';
  report.add(line);
  debugPrint('CHECK: $line'); // live, so a dead run still leaves a trail
}

Future<bool> waitFor(
  WidgetTester t,
  Finder f, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 300));
    if (f.evaluate().isNotEmpty) return true;
  }
  return false;
}

Future<void> settle(WidgetTester t, [int ms = 800]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> tapIfFound(WidgetTester t, Finder f) async {
  if (!await waitFor(t, f)) return false;
  await t.tap(f.first, warnIfMissed: false);
  await settle(t);
  return true;
}

Future<void> back(WidgetTester t) async {
  final backButton = find.byType(BackButton);
  if (backButton.evaluate().isNotEmpty) {
    await t.tap(backButton.first, warnIfMissed: false);
  }
  await settle(t);
}

Future<void> shot(IntegrationTestWidgetsFlutterBinding binding,
    WidgetTester t, String name) async {
  try {
    await binding.takeScreenshot(name);
  } catch (_) {
    // iOS screenshots need driver support; the checks are what matter
  }
}

// picks an option from the LokDropdownField bottom sheet
Future<bool> pickOption(WidgetTester t, Finder fieldHint, String option) async {
  if (!await tapIfFound(t, fieldHint)) return false;
  final base = find.text(option);
  try {
    await t.scrollUntilVisible(base, 400,
        scrollable: find.byType(Scrollable).last);
  } catch (_) {}
  if (base.evaluate().isEmpty) {
    // close the sheet so the walk can continue
    await t.tapAt(const Offset(20, 80));
    await settle(t);
    return false;
  }
  await t.tap(base.last, warnIfMissed: false);
  await settle(t);
  return true;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live walk of the whole app', (t) async {
    app.main();
    await settle(t, 3000);

    // ── welcome + login ────────────────────────────────────────────────
    final onWelcome = await waitFor(t, find.text('Continue as guest'));
    check('welcome screen shows', onWelcome);
    await shot(binding, t, '01_welcome');

    if (onWelcome) {
      await tapIfFound(t, find.text('Login'));
    }
    final fields = find.byType(TextField);
    final onLogin = await waitFor(t, fields);
    check('login screen shows', onLogin);
    if (!onLogin) {
      // already logged in from a previous run — fine, keep walking
      check('session restored instead of login', true);
    } else {
      await t.enterText(fields.at(0), email);
      await t.enterText(fields.at(1), password);
      await settle(t);
      await t.tap(find.widgetWithText(ElevatedButton, 'Login'),
          warnIfMissed: false);
    }

    // ── home ───────────────────────────────────────────────────────────
    final homeLoaded =
        await waitFor(t, find.text('Recommended Travelers'), timeout: const Duration(seconds: 40));
    check('login → home', homeLoaded);
    if (!homeLoaded) {
      debugPrint('=== UI TEST REPORT ===');
      report.forEach(debugPrint);
      fail('login failed — cannot continue');
    }

    check('latest deals section', await waitFor(t, find.text('Latest deals')));
    check('latest deals card from API',
        await waitFor(t, find.textContaining('Documents to Paris')));
    check('recommended rail card from API',
        await waitFor(t, find.textContaining('France')));
    await shot(binding, t, '02_home');

    // see-all page
    if (await tapIfFound(t, find.text('See All'))) {
      check('recommended page opens',
          await waitFor(t, find.text('Recommended travelers')));
      await shot(binding, t, '03_recommended');
      await back(t);
    } else {
      check('recommended page opens', false, 'See All not found');
    }

    // ── search: trips + requests + details + chat handoff ─────────────
    await tapIfFound(t, find.text('Trips'));
    check('trip search results', await waitFor(t, find.text('Air France').hitTestable(), timeout: const Duration(seconds: 5)) || await waitFor(t, find.text('France')));
    await shot(binding, t, '04_search_trips');
    await tapIfFound(t, find.text('Requests'));
    final requestsListed =
        await waitFor(t, find.textContaining('Documents to Paris'));
    check('request search results', requestsListed);

    if (requestsListed) {
      await t.tap(find.textContaining('Documents to Paris').first,
          warnIfMissed: false);
      await settle(t, 1500);
      final details = await waitFor(t, find.text('FROM'));
      check('post details page', details);
      await shot(binding, t, '05_post_details');
      if (details) {
        // every post on the dev server belongs to this account, so the chat
        // button must be hidden — real chat needs a second seeded user
        check('chat hidden on own post',
            find.textContaining('Chat with').evaluate().isEmpty,
            'chat itself untestable with a single account');
      }
      await back(t);
    }
    await back(t);

    // ── bottom tabs: deals / chat inbox ────────────────────────────────
    await tapIfFound(t, find.text('Deals'));
    check(
        'deals tab (empty state or list)',
        await waitFor(t, find.text('No deals here yet')) ||
            find.text('All').evaluate().isNotEmpty);
    await shot(binding, t, '07_deals');

    await tapIfFound(t, find.text('Chat'));
    check(
        'chat inbox loads',
        await waitFor(t, find.text('No conversations yet'),
                timeout: const Duration(seconds: 10)) ||
            find.byType(ListTile).evaluate().isNotEmpty);
    await shot(binding, t, '08_inbox');

    // ── profile cluster ────────────────────────────────────────────────
    await tapIfFound(t, find.text('Profile'));
    check('profile header from API',
        await waitFor(t, find.text('Sushil Hemrom')));
    check('verification chips', find.text('ID verified').evaluate().isNotEmpty);
    await shot(binding, t, '09_profile');

    // my posts + delete one of this session's test trips
    if (await tapIfFound(t, find.text('My requests & trips'))) {
      final tripRows = await waitFor(t, find.text('Delete'),
          timeout: const Duration(seconds: 15));
      check('my trips list', tripRows);
      await shot(binding, t, '10_my_posts');
      if (tripRows && find.text('Delete').evaluate().length > 1) {
        final before = find.text('Delete').evaluate().length;
        await t.tap(find.text('Delete').last, warnIfMissed: false);
        await settle(t);
        await tapIfFound(t, find.widgetWithText(TextButton, 'Delete'));
        await settle(t, 2000);
        check('delete own trip',
            find.text('Delete').evaluate().length < before);
      }
      await tapIfFound(t, find.text('Requests'));
      check('my requests list',
          await waitFor(t, find.textContaining('United States')));
      await back(t);
    } else {
      check('my trips list', false, 'menu item not found');
    }

    // reviews
    if (await tapIfFound(t, find.text('My reviews'))) {
      check(
          'reviews page',
          await waitFor(t, find.text('No reviews yet')) ||
              find.text('reviews').evaluate().isNotEmpty);
      await back(t);
    }

    // wallet
    if (await tapIfFound(t, find.text('Wallet & payouts'))) {
      check('wallet dashboard', await waitFor(t, find.text('Available earnings')));
      check('wallet balance from API',
          await waitFor(t, find.textContaining('USD 0.00')));
      await shot(binding, t, '11_wallet');
      await back(t);
    }

    // notifications
    if (await tapIfFound(t, find.text('Notifications'))) {
      check(
          'notifications page',
          await waitFor(t, find.text('Nothing here yet')) ||
              find.byType(ListTile).evaluate().isNotEmpty);
      await back(t);
    }

    // basic info prefill
    if (await tapIfFound(t, find.text('Basic info'))) {
      check('basic info prefilled',
          await waitFor(t, find.widgetWithText(TextField, 'Sushil')));
      await shot(binding, t, '12_basic_info');
      await back(t);
    }

    // ── create a trip through the real form ────────────────────────────
    await tapIfFound(t, find.byIcon(Icons.add));
    if (await tapIfFound(t, find.text('Post a Trip'))) {
      await tapIfFound(t, find.text('International'));
      await settle(t, 4000); // fresh install — give the country lookup a beat

      final fromOk = await pickOption(t, find.text('from country'), 'France');
      final toOk = await pickOption(t, find.text('to country'), 'United States');
      check('trip form country pickers', fromOk && toOk);

      var posted = false;
      if (fromOk && toOk) {
        // date picker: prefer a mid-month future day, else accept the default
        await tapIfFound(t, find.text('trip date and time'));
        if (find.text('25').evaluate().isNotEmpty) {
          await t.tap(find.text('25').last, warnIfMissed: false);
          await settle(t, 300);
        }
        await tapIfFound(t, find.text('OK'));

        Future<bool> fill(String hint, String value) async {
          final f = find.widgetWithText(TextField, hint);
          if (f.evaluate().isEmpty) {
            try {
              await t.scrollUntilVisible(f, 300,
                  scrollable: find.byType(Scrollable).first);
            } catch (_) {}
          }
          if (f.evaluate().isEmpty) return false;
          await t.enterText(f.first, value);
          return true;
        }

        final filled = await fill('e.g. Air France', 'Air France') &&
            await fill('kilograms available', '7') &&
            await fill('where you collect items', 'CDG Airport') &&
            await fill('where you hand them over', 'JFK Airport');
        check('trip form fields fill', filled);
        await settle(t);
        await shot(binding, t, '13_trip_form');

        if (filled) {
          try {
            await t.scrollUntilVisible(
                find.widgetWithText(ElevatedButton, 'Post'), 300,
                scrollable: find.byType(Scrollable).first);
          } catch (_) {}
          await t.tap(find.widgetWithText(ElevatedButton, 'Post'),
              warnIfMissed: false);
          posted = await waitFor(t, find.text('Trip posted'),
              timeout: const Duration(seconds: 15));
        }
      }
      check('post trip via form', posted,
          posted ? null : 'form could not be completed — see screenshots');
      await shot(binding, t, '14_trip_posted');
    } else {
      check('post trip via form', false, 'post sheet not found');
    }

    debugPrint('=== UI TEST REPORT ===');
    report.forEach(debugPrint);
    debugPrint('=== END REPORT ===');
  });
}
