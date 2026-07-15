import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/utils/notify.dart';
import '../../../lookups/data/lookup_models.dart';
import '../../../lookups/data/lookups_repository.dart';
import '../../../posts/data/models/post_model.dart';
import '../../../posts/data/posts_repository.dart';

class PostTripController extends GetxController {
  final location = Rx<PostLocation?>(null);

  final insideCountry = RxnString();
  final fromCountry = RxnString();
  final toCountry = RxnString();
  final fromCity = RxnString();
  final toCity = RxnString();
  final date = Rxn<DateTime>();
  final noSpecificDate = false.obs;
  final rejectedCategory = RxnString();

  final weight = TextEditingController();
  final notes = TextEditingController();
  final airline = TextEditingController(); // API requires it for international
  final pickupLocation = TextEditingController(); // API requires both of these
  final dropoffLocation = TextEditingController();

  final busy = false.obs;
  final countries = <Country>[].obs;
  final cities = <City>[].obs;
  final categories = <Category>[].obs;

  final _repo = PostsRepository();
  final _lookups = LookupsRepository();

  bool get isLocal => location.value == PostLocation.local;

  List<String> get countryNames => countries.map((e) => e.name).toList();
  List<String> get cityNames => cities.map((e) => e.name).toList();
  List<String> get categoryNames => categories.map((e) => e.title).toList();

  @override
  void onInit() {
    super.onInit();
    _lookups.countries().then(countries.assignAll).catchError((_) {});
    _lookups.categories().then(categories.assignAll).catchError((_) {});
    ever(insideCountry, (name) {
      fromCity.value = null;
      toCity.value = null;
      final country = _byName(name);
      if (country != null) {
        _lookups.cities(country.iso2).then(cities.assignAll).catchError((_) {});
      }
    });
  }

  Country? _byName(String? name) =>
      countries.firstWhereOrNull((e) => e.name == name);
  City? _cityByName(String? name) => cities.firstWhereOrNull((e) => e.name == name);

  Future<void> submit() async {
    final origin = _byName(isLocal ? insideCountry.value : fromCountry.value);
    final kg = double.tryParse(weight.text);

    if (origin == null || kg == null) {
      toast('Fill in the route and weight first');
      return;
    }
    if (isLocal && (fromCity.value == null || toCity.value == null)) {
      toast('Pick the from and to cities');
      return;
    }
    if (!isLocal && toCountry.value == null) {
      toast('Pick a destination country');
      return;
    }
    if (!isLocal && airline.text.trim().isEmpty) {
      toast('Airline is required for international trips');
      return;
    }
    if (date.value == null && !noSpecificDate.value) {
      toast('Pick a trip date');
      return;
    }
    if (pickupLocation.text.trim().isEmpty || dropoffLocation.text.trim().isEmpty) {
      toast('Add the pickup and dropoff locations');
      return;
    }

    final rejected = categories
        .where((c) => c.title == rejectedCategory.value)
        .map((c) => c.id)
        .toList();

    busy.value = true;
    try {
      await _repo.addTrip(
        local: isLocal,
        country: origin,
        toCountry: isLocal ? origin : _byName(toCountry.value),
        fromCity: _cityByName(fromCity.value),
        toCity: _cityByName(toCity.value),
        date: date.value ?? DateTime.now().add(const Duration(days: 1)),
        airline: airline.text.trim(),
        weight: kg,
        pickupLocation: pickupLocation.text.trim(),
        dropoffLocation: dropoffLocation.text.trim(),
        rejectedCategoryIds: rejected,
      );
      toast('Trip posted');
      Get.back();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      busy.value = false;
    }
  }

  @override
  void onClose() {
    weight.dispose();
    notes.dispose();
    airline.dispose();
    pickupLocation.dispose();
    dropoffLocation.dispose();
    super.onClose();
  }
}
