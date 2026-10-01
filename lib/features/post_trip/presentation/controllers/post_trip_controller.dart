import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/utils/notify.dart';
import '../../../lookups/data/lookup_models.dart';
import '../../../lookups/data/lookups_repository.dart';
import '../../../posts/data/models/post_model.dart';
import '../../../posts/data/posts_repository.dart';

class PostTripController extends GetxController {
  // set when the form is opened to edit an existing trip
  final int? editId;
  PostTripController({this.editId});

  bool get isEditing => editId != null;

  final location = Rx<PostLocation?>(null);

  final insideCountry = RxnString();
  final fromCountry = RxnString();
  final toCountry = RxnString();
  final fromCity = RxnString();
  final toCity = RxnString();
  final date = Rxn<DateTime>();
  final noSpecificDate = false.obs;
  // live mode lets a traveler rule out several categories at once
  final rejectedCategories = <String>[].obs;

  final weight = TextEditingController();
  final notes = TextEditingController();
  final airline = TextEditingController(); // API requires it for international
  final pickupLocation = TextEditingController(); // API requires both of these
  final dropoffLocation = TextEditingController();

  final busy = false.obs;
  final lookupFailed = false.obs; // countries/categories couldn't be loaded
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
    _bootstrap();
    ever(insideCountry, (name) {
      fromCity.value = null;
      toCity.value = null;
      final country = _byName(name);
      if (country != null) {
        _lookups.cities(country.iso2).then(cities.assignAll).catchError((_) {});
      }
    });
  }

  // lookups first, then pull the post being edited so names can be matched
  Future<void> loadLookups() => _bootstrap();

  Future<void> _bootstrap() async {
    lookupFailed.value = false;
    try {
      countries.assignAll(await _lookups.countries());
      if (countries.isEmpty) lookupFailed.value = true;
    } catch (_) {
      lookupFailed.value = true;
    }
    _lookups.categories().then(categories.assignAll).catchError((_) {});
    if (isEditing) await _prefill();
  }

  Future<void> _prefill() async {
    busy.value = true;
    try {
      final post = await _repo.getById(editId!);
      location.value = post.location;
      if (post.isLocal) {
        insideCountry.value = post.fromCountry;
        // cities load off the insideCountry watcher, so wait before selecting
        await Future.delayed(const Duration(milliseconds: 400));
        fromCity.value = post.fromCity;
        toCity.value = post.toCity;
      } else {
        fromCountry.value = post.fromCountry;
        toCountry.value = post.toCountry;
      }
      date.value = post.date;
      weight.text = post.weight == 0 ? '' : post.weight.toStringAsFixed(0);
      airline.text = post.airline ?? '';
      pickupLocation.text = post.pickupLocation ?? '';
      dropoffLocation.text = post.dropoffLocation ?? '';
      notes.text = post.notes ?? '';
      rejectedCategories.assignAll(post.rejectedCategories);
    } on AppException catch (e) {
      toastError(e);
    } finally {
      busy.value = false;
    }
  }

  Country? _byName(String? name) =>
      countries.firstWhereOrNull((e) => e.name == name);
  City? _cityByName(String? name) => cities.firstWhereOrNull((e) => e.name == name);

  Future<void> submit() async {
    final origin = _byName(isLocal ? insideCountry.value : fromCountry.value);
    final kg = double.tryParse(weight.text);

    if (origin == null || kg == null) {
      toast('fill_in_the_route_and_weight_first'.tr);
      return;
    }
    if (isLocal && (fromCity.value == null || toCity.value == null)) {
      toast('pick_the_from_and_to_cities'.tr);
      return;
    }
    if (!isLocal && toCountry.value == null) {
      toast('pick_a_destination_country'.tr);
      return;
    }
    if (date.value == null && !noSpecificDate.value) {
      toast('pick_a_trip_date'.tr);
      return;
    }
    final rejected = categories
        .where((c) => rejectedCategories.contains(c.title))
        .map((c) => c.id)
        .toList();

    // trips don't ask for pickup/dropoff in live mode; the repository posts the
    // same placeholder the website does so the API's required rule still passes
    const from = '';
    const to = '';

    busy.value = true;
    try {
      final tripDate = date.value ?? DateTime.now().add(const Duration(days: 1));
      if (isEditing) {
        await _repo.updateTrip(
          editId!,
          local: isLocal,
          country: origin,
          toCountry: isLocal ? origin : _byName(toCountry.value),
          fromCity: _cityByName(fromCity.value),
          toCity: _cityByName(toCity.value),
          date: tripDate,
          weight: kg,
          pickupLocation: from,
          dropoffLocation: to,
          rejectedCategoryIds: rejected,
          notes: notes.text.trim(),
          noSpecificDate: noSpecificDate.value,
        );
      } else {
        await _repo.addTrip(
          local: isLocal,
          country: origin,
          toCountry: isLocal ? origin : _byName(toCountry.value),
          fromCity: _cityByName(fromCity.value),
          toCity: _cityByName(toCity.value),
          date: tripDate,
          weight: kg,
          pickupLocation: from,
          dropoffLocation: to,
          rejectedCategoryIds: rejected,
          notes: notes.text.trim(),
          noSpecificDate: noSpecificDate.value,
        );
      }
      toast(isEditing ? 'trip_updated'.tr : 'trip_posted'.tr);
      Get.back(result: true);
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
