import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../posts/data/models/post_model.dart';

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

  bool get isLocal => location.value == PostLocation.local;
  bool get isBuy => wantTo.value == WantTo.buyAndDeliver;

  @override
  void onClose() {
    itemName.dispose();
    weight.dispose();
    description.dispose();
    profit.dispose();
    super.onClose();
  }
}
