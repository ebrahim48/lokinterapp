import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/utils/notify.dart';
import '../../../lookups/data/lookup_models.dart';
import '../../../lookups/data/lookups_repository.dart';
import '../../../posts/data/models/post_model.dart';
import '../../../posts/data/posts_repository.dart';

class PostRequestController extends GetxController {
  // set when the form is opened to edit an existing request
  final int? editId;
  PostRequestController({this.editId});

  bool get isEditing => editId != null;

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
  final picturePath = RxnString(); // local file uploaded as attachFile
  final currency = 'USD'.obs;
  final acceptedTerms = false.obs;

  final itemName = TextEditingController();
  final weight = TextEditingController();
  final description = TextEditingController();
  final profit = TextEditingController();
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
  bool get isBuy => wantTo.value == WantTo.buyAndDeliver;

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
    try {
      categories.assignAll(await _lookups.categories());
    } catch (_) {}
    if (isEditing) await _prefill();
  }

  Future<void> _prefill() async {
    busy.value = true;
    try {
      final post = await _repo.getById(editId!);
      wantTo.value = post.wantTo;
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
      beforeDate.value = post.date;
      itemName.text = post.title ?? '';
      weight.text = post.weight == 0 ? '' : post.weight.toStringAsFixed(0);
      description.text = post.description ?? '';
      pickupLocation.text = post.pickupLocation ?? '';
      dropoffLocation.text = post.dropoffLocation ?? '';
      category.value = post.category;
      acceptedTerms.value = true; // already agreed when first posted
    } on AppException catch (e) {
      toastError(e);
    } finally {
      busy.value = false;
    }
  }

  Country? _byName(String? name) =>
      countries.firstWhereOrNull((e) => e.name == name);
  City? _cityByName(String? name) => cities.firstWhereOrNull((e) => e.name == name);

  /// Product picture — gallery pick, ≤5MB (API limit, same as the website).
  Future<void> pickProductPicture() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (img == null) return;
    final bytes = await img.length();
    if (bytes > 5 * 1024 * 1024) {
      toast('please_pick_an_image_under_5mb'.tr);
      return;
    }
    picturePath.value = img.path;
    pictureName.value = img.name;
  }

  Future<void> submit() async {
    final origin = _byName(isLocal ? insideCountry.value : fromCountry.value);
    final kg = double.tryParse(weight.text);
    final cat = categories.firstWhereOrNull((c) => c.title == category.value);

    if (origin == null || kg == null || cat == null || beforeDate.value == null) {
      toast('fill_in_the_route_weight_category_and_date_first'.tr);
      return;
    }
    if (isBuy && itemName.text.trim().isEmpty) {
      toast('give_the_item_a_name'.tr);
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
    // only a local request asks for these; international falls back to the route
    if (isLocal &&
        (pickupLocation.text.trim().isEmpty || dropoffLocation.text.trim().isEmpty)) {
      toast('add_the_pickup_and_dropoff_locations'.tr);
      return;
    }
    // international requests hide these; the repository posts the website's
    // placeholder for whatever is left blank
    final pickup = pickupLocation.text.trim();
    final dropoff = dropoffLocation.text.trim();
    if (!acceptedTerms.value) {
      toast('accept_the_terms_and_conditions_first'.tr);
      return;
    }

    busy.value = true;
    try {
      final title = itemName.text.trim().isEmpty
          ? '${origin.name} delivery'
          : itemName.text.trim();
      if (isEditing) {
        await _repo.updateRequest(
          editId!,
          local: isLocal,
          buyAndDeliver: isBuy,
          title: title,
          country: origin,
          toCountry: isLocal ? origin : _byName(toCountry.value),
          fromCity: _cityByName(fromCity.value),
          toCity: _cityByName(toCity.value),
          date: beforeDate.value!,
          weight: kg,
          categoryId: cat.id,
          pickupLocation: pickup,
          dropoffLocation: dropoff,
          description: description.text.trim(),
          attachFilePath: picturePath.value,
        );
        toast('delivery_request_updated'.tr);
        Get.back(result: true);
        return;
      }
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
        pickupLocation: pickup,
        dropoffLocation: dropoff,
        description: description.text.trim(),
        attachFilePath: picturePath.value,
      );
      toast('delivery_request_posted'.tr);
      Get.back(result: true);
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
