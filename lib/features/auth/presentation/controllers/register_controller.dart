import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum RegisterRole { transporter, individual }

class RegisterController extends GetxController {
  final role = RegisterRole.individual.obs;
  final country = RxnString();
  final operatingCountry = RxnString();
  final documentName = RxnString(); // business legal documents
  final licenseName = RxnString(); // transportation license

  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final businessName = TextEditingController();
  final address = TextEditingController();

  bool get isTransporter => role.value == RegisterRole.transporter;

  @override
  void onClose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    email.dispose();
    businessName.dispose();
    address.dispose();
    super.onClose();
  }
}
