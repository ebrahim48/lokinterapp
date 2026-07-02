import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../posts/data/models/post_model.dart';

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

  bool get isLocal => location.value == PostLocation.local;

  @override
  void onClose() {
    weight.dispose();
    super.onClose();
  }
}
