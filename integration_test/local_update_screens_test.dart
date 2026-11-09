// Nov 2026 local & international update — walks the new screens on a
// simulator/device against the live API and screenshots each one.
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/local_update_screens_test.dart -d <device>
// Every step runs even if an earlier one fails; screenshots land in
// build/ui_shots/.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_task/core/services/session_service.dart';
import 'package:flutter_task/core/widgets/location_picker_page.dart';
import 'package:flutter_task/features/chat/presentation/chat_conversation_page.dart';
import 'package:flutter_task/features/deals/data/deal_model.dart';
import 'package:flutter_task/features/deals/data/deals_repository.dart';
import 'package:flutter_task/features/deals/presentation/deal_details_page.dart';
import 'package:flutter_task/features/deals/presentation/track_order_page.dart';
import 'package:flutter_task/features/fees/presentation/fee_ledgers_page.dart';
import 'package:flutter_task/features/fees/presentation/invoices_page.dart';
import 'package:flutter_task/features/posts/data/posts_repository.dart';
import 'package:flutter_task/features/post_trip/presentation/controllers/post_trip_controller.dart';
import 'package:flutter_task/features/post_trip/presentation/post_trip_page.dart';
import 'package:flutter_task/main.dart' as app;

Future<void> settle(WidgetTester t, [int ms = 3000]) async {
  for (var i = 0; i < ms ~/ 250; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<bool> pumpUntil(WidgetTester t, Finder f, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 4; i++) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return true;
  }
  return false;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local/international update screens', (t) async {
    await app.main();
    await settle(t, 4000);
    await binding.convertFlutterSurfaceToImage();
    await t.pump();
    final failures = <String>[];

    Future<void> step(String name, Future<void> Function() body) async {
      try {
        await body();
        debugPrint('STEP OK: $name');
      } catch (e) {
        failures.add('$name: $e');
        debugPrint('STEP FAILED: $name — $e');
      }
      // back to the shell for the next step
      while (Get.key.currentState?.canPop() ?? false) {
        Get.back();
        await settle(t, 600);
      }
    }

    Future<void> shot(String name) async {
      await t.pump();
      await binding.takeScreenshot(name);
    }

    await step('login', () async {
      final session = Get.find<SessionService>();
      if (!session.loggedIn) {
        await pumpUntil(t, find.text('welcome.login'.tr));
        await t.tap(find.text('welcome.login'.tr));
        await settle(t, 1500);
        final fields = find.byType(TextField);
        await t.enterText(fields.at(0), 'test@gmail.com');
        await t.enterText(fields.at(1), '12345678');
        await t.tap(find.text('login'.tr).last);
      }
      expect(await pumpUntil(t, find.text('nav.deals'.tr), seconds: 30), isTrue);
      await settle(t, 4000);
      final u = session.user.value;
      debugPrint('USER id=${u?.id} transporter=${u?.isVerifiedTransporter} '
          'restricted=${u?.feeRestricted}');
      await shot('u01_home');
    });

    await step('post menu', () async {
      await t.tap(find.byIcon(Icons.add));
      await settle(t, 1500);
      await shot('u02_post_menu');
    });

    await step('post trip — Tunisia local', () async {
      Get.to(() => const PostTripPage());
      await settle(t, 4000);
      final c = Get.find<PostTripController>(tag: 'new');
      await t.tap(find.text('local'.tr).first);
      await settle(t, 1000);
      final tn = c.countryNames.firstWhereOrNull(
          (n) => n.toLowerCase() == 'tunisia' || n.toLowerCase() == 'tunisie');
      debugPrint('TN country found: $tn');
      if (tn != null) c.insideCountry.value = tn;
      await settle(t, 2000);
      debugPrint('local trip blocked: ${c.localTripBlocked}');
      await shot('u03_post_trip_local');
    });

    await step('local deal form', () async {
      final posts = await PostsRepository().search(
        searchAs: 'TRIP',
        filters: {'postLocation': 'LOCAL', 'country': 'TN'},
      );
      final me = Get.find<SessionService>().user.value?.id;
      final post = posts.list.firstWhereOrNull((p) => p.user.id != me && p.user.id != 0);
      debugPrint('local trip posts: ${posts.list.length}, picked: ${post?.id}');
      if (post == null) throw 'no local trip post from someone else';
      Get.to(() => ChatConversationPage(user: post.user, postId: post.id));
      final bar = find.text('confirm_agreement_continue'.tr);
      if (!await pumpUntil(t, bar, seconds: 20)) {
        await shot('u04_chat_no_confirm_bar');
        throw 'no confirm bar (a deal may already be live in this chat)';
      }
      await t.tap(bar);
      await settle(t, 3000);
      await shot('u04_local_deal_form_top');
      final sheet = find.byType(SingleChildScrollView).last;
      await t.drag(sheet, const Offset(0, -700));
      await settle(t, 1000);
      await shot('u05_local_deal_form_middle');
      await t.drag(sheet, const Offset(0, -900));
      await settle(t, 1000);
      await shot('u06_local_deal_form_bottom');
    });

    List<Deal> deals = const [];
    await step('load deals', () async {
      deals = await DealsRepository().list('ALL');
      debugPrint('deals: ${deals.length}, local: ${deals.where((d) => d.isLocal).length}, '
          'ongoing local: ${deals.where((d) => d.isLocal && d.status == DealStatus.outgoing).length}');
    });

    Deal? pick() =>
        deals.firstWhereOrNull((d) => d.isLocal && d.status == DealStatus.outgoing) ??
        deals.firstWhereOrNull((d) => d.isLocal && d.status == DealStatus.accepted) ??
        deals.firstWhereOrNull((d) => d.status == DealStatus.accepted) ??
        deals.firstOrNull;

    await step('deal details (QR / tracking button)', () async {
      final d = pick();
      if (d == null) throw 'no deals on this account';
      debugPrint('deal ${d.id} local=${d.isLocal} status=${d.status} sender=${d.isSender}');
      Get.to(() => DealDetailsPage(deal: d));
      await settle(t, 6000);
      await shot('u07_deal_details_top');
      final scroll = find.byType(Scrollable).first;
      await t.drag(scroll, const Offset(0, -700));
      await settle(t, 1200);
      await shot('u08_deal_details_middle');
      await t.drag(scroll, const Offset(0, -900));
      await settle(t, 1200);
      await shot('u09_deal_details_bottom');
      debugPrint('QR card: ${find.text('share_qr_code'.tr).evaluate().length}, '
          'track button: ${find.text('track_my_order'.tr).evaluate().length}');
    });

    await step('track my order', () async {
      final d = pick();
      if (d == null) throw 'no deals on this account';
      Get.to(() => TrackOrderPage(deal: d));
      await settle(t, 8000);
      await shot('u10_track_my_order');
    });

    await step('location picker', () async {
      Get.to(() => const LocationPickerPage(title: 'Pickup location'));
      await settle(t, 8000);
      await shot('u11_location_picker');
    });

    await step('fee ledgers', () async {
      Get.to(() => const FeeLedgersPage());
      await settle(t, 5000);
      await shot('u12_fee_ledgers');
    });

    await step('invoices', () async {
      Get.to(() => const InvoicesPage());
      await settle(t, 5000);
      await shot('u13_invoices');
    });

    await step('profile menu', () async {
      await t.tap(find.text('nav.profile'.tr));
      await settle(t, 2500);
      await shot('u14_profile');
    });

    debugPrint('FAILURES (${failures.length}):\n${failures.join('\n')}');
  });
}
