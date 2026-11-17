// Deal pickup / drop-off map + location picker, on a real emulator/device.
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/places_map_test.dart -d <device>
// Prints "SHOT:<name>" while a screen is held still, so a screen recorder
// (adb screencap) can grab the real map tiles — GoogleMap is a platform view
// and does not show up in Flutter's own screenshots.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_task/core/widgets/location_picker_page.dart';
import 'package:flutter_task/core/widgets/places_map.dart';
import 'package:flutter_task/main.dart' as app;

Future<void> settle(WidgetTester t, [int ms = 3000]) async {
  for (var i = 0; i < ms ~/ 250; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<void> shot(WidgetTester t, String name) async {
  debugPrint('SHOT:$name');
  await settle(t, 5000); // held still while the recorder grabs it
}

// Tunis start point of the picker — a Dhaka address must never be saved with it
const tunis = LatLng(36.8065, 10.1815);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('places map + picker coordinates', (t) async {
    await app.main();
    await settle(t, 5000);

    // 0 — the From / To pins themselves, drawn on a grey card (they are
    // map marker images, so they can be checked without map tiles)
    final dpr = t.view.devicePixelRatio;
    final from = await PlaceLabelMarker.paint('From: Dhanmondi, Bangladesh', pickupDotColor, dpr);
    final to = await PlaceLabelMarker.paint('To: Farmgate, Dhaka', dropoffDotColor, dpr);
    Get.to(() => Scaffold(
          appBar: AppBar(title: const Text('Pins')),
          body: Container(
            color: const Color(0xFFE8EAED),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.memory(from, scale: dpr),
              const SizedBox(height: 30),
              Image.memory(to, scale: dpr),
            ]),
          ),
        ));
    await settle(t, 2000);
    await shot(t, 'pins');
    Get.back();
    await settle(t, 1000);

    // 1 — deal map: Dhanmondi → Farmgate, labelled From / To
    Get.to(() => Scaffold(
          appBar: AppBar(title: const Text('Places map')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              PlacesMap(
                pickup: LatLng(23.7461, 90.3742),
                pickupLabel: 'Dhanmondi, Bangladesh, Dhaka',
                dropoff: LatLng(23.7576, 90.3897),
                dropoffLabel: 'Farmgate, Dhaka, Bangladesh',
                height: 260,
              ),
            ],
          ),
        ));
    await settle(t, 8000);
    expect(find.byType(PlacesMap), findsOneWidget);
    await shot(t, 'places_map');
    Get.back();
    await settle(t, 1000);

    // 2 — picker: search a Dhaka address, confirm, check the returned point
    PickedPlace? picked;
    Get.to(() => const LocationPickerPage(title: 'Pickup'))!.then((v) => picked = v as PickedPlace?);
    await settle(t, 6000);
    await t.enterText(find.byType(TextField).first, 'Farmgate, Dhaka, Bangladesh');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await settle(t, 10000); // geocode + camera animation + reverse geocode
    await shot(t, 'picker_after_search');

    final confirm = find.text('confirm_this_location'.tr);
    expect(confirm, findsOneWidget);
    // wait until the address for the new spot is in and the button is live
    for (var i = 0; i < 60; i++) {
      final btn = t.widget<ElevatedButton>(
          find.ancestor(of: confirm, matching: find.byType(ElevatedButton)));
      if (btn.onPressed != null) break;
      await t.pump(const Duration(milliseconds: 250));
    }
    await t.tap(confirm);
    await settle(t, 2000);

    debugPrint('PICKED: ${picked?.label} @ ${picked?.lat}, ${picked?.lng}');
    expect(picked, isNotNull);
    // Dhaka is around 23.7N 90.4E — nowhere near the Tunis start point
    expect((picked!.lat - 23.75).abs() < 0.3, isTrue, reason: 'lat ${picked!.lat}');
    expect((picked!.lng - 90.39).abs() < 0.3, isTrue, reason: 'lng ${picked!.lng}');
    expect(picked!.lat == tunis.latitude && picked!.lng == tunis.longitude, isFalse);
  });
}
