import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/utils/notify.dart';
import '../../../lookups/data/lookup_models.dart';
import '../../../lookups/data/lookups_repository.dart';
import '../../../posts/data/models/post_model.dart';
import '../../../posts/data/posts_repository.dart';

class PostRequestController extends GetxController {
  final wantTo = Rx<WantTo?>(null);
  final location = Rx<PostLocation?>(null);

  final insideCountry = RxnString();
  final fromCountry = RxnString();
  final toCountry = RxnString();
  final fromCity = RxnString();
  final toCity = RxnString();
  final beforeDate = Rxn<DateTime>();
  final category = RxnString();
  final pictureName = RxnString();
  final currency = 'USD'.obs;
  final acceptedTerms = false.obs;

  final itemName = TextEditingController();
  final weight = TextEditingController();
  final description = TextEditingController();
  final profit = TextEditingController();
  final pickupLocation = TextEditingController(); // API requires both of these
  final dropoffLocation = TextEditingController();

  final busy = false.obs;
  final countries = <Country>[].obs;
  final cities = <City>[].obs;
  final categories = <Category>[].obs;

  final _repo = PostsRepository();
  final _lookups = LookupsRepository();

  bool get isLocal => location.value == PostLocation.local;
  bool get isBuy => wantTo.value == WantTo.buyAndDeliver;

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
    final cat = categories.firstWhereOrNull((c) => c.title == category.value);

    if (origin == null || kg == null || cat == null || beforeDate.value == null) {
      toast('Fill in the route, weight, category and date first');
      return;
    }
    if (isBuy && itemName.text.trim().isEmpty) {
      toast('Give the item a name');
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
    if (pickupLocation.text.trim().isEmpty || dropoffLocation.text.trim().isEmpty) {
      toast('Add the pickup and dropoff locations');
      return;
    }
    if (!acceptedTerms.value) {
      toast('Accept the terms and conditions first');
      return;
    }

    busy.value = true;
    try {
      await _repo.addRequest(
        local: isLocal,
        buyAndDeliver: isBuy,
        title: itemName.text.trim().isEmpty
            ? '${origin.name} delivery'
            : itemName.text.trim(),
        country: origin,
        toCountry: isLocal ? origin : _byName(toCountry.value),
        fromCity: _cityByName(fromCity.value),
        toCity: _cityByName(toCity.value),
        date: beforeDate.value!,
        weight: kg,
        categoryId: cat.id,
        pickupLocation: pickupLocation.text.trim(),
        dropoffLocation: dropoffLocation.text.trim(),
        description: description.text.trim(),
      );
      toast('Delivery request posted');
      Get.back();
    } on AppException catch (e) {
      toastError(e);
    } finally {
      busy.value = false;
    }
  }

  @override
  void onClose() {
    itemName.dispose();
    weight.dispose();
    description.dispose();
    profit.dispose();
    pickupLocation.dispose();
    dropoffLocation.dispose();
    super.onClose();
  }
}
