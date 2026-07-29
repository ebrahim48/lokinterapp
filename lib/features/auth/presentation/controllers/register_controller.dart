import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/utils/notify.dart';
import '../../../../core/utils/validators.dart';
import '../../../lookups/data/lookup_models.dart';
import '../../../lookups/data/lookups_repository.dart';
import '../../../shell/presentation/main_shell.dart';
import '../../data/auth_repository.dart';
import '../otp_page.dart';

enum RegisterRole { transporter, individual }

class RegisterController extends GetxController {
  final role = RegisterRole.individual.obs;
  final country = RxnString();
  final operatingCountries = <String>[].obs;
  final licenseFile = Rxn<PlatformFile>(); // transport license
  final legalFile = Rxn<PlatformFile>(); // transporter legal documents

  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final businessName = TextEditingController();
  final address = TextEditingController();

  final busy = false.obs;
  final countries = <Country>[].obs;

  final _repo = AuthRepository();
  final _lookups = LookupsRepository();

  bool get isTransporter => role.value == RegisterRole.transporter;

  List<String> get countryNames => countries.map((c) => c.name).toList();

  // the backend wants ISO2 codes, the dropdowns show names
  List<String> get operatingCountriesIso => operatingCountries
      .map((name) => countries.firstWhereOrNull((c) => c.name == name)?.iso2)
      .whereType<String>()
      .toList();

  // legal docs go into businessDocuments[]; the transport license is its own field
  List<PlatformFile> get businessDocuments =>
      [legalFile.value].whereType<PlatformFile>().toList();

  @override
  void onInit() {
    super.onInit();
    _lookups.countries().then(countries.assignAll).catchError((_) {});
    // live mode: picking the country of residence fills in its dial code
    ever(country, (name) {
      final c = countries.firstWhereOrNull((e) => e.name == name);
      if (c == null || c.phoneCode.isEmpty) return;
      final prefix = '+${c.phoneCode}';
      // keep whatever the user already typed after the old prefix
      final rest = phone.text.startsWith('+')
          ? phone.text.replaceFirst(RegExp(r'^\+\d{1,4}'), '')
          : phone.text;
      phone.text = '$prefix$rest';
      phone.selection =
          TextSelection.fromPosition(TextPosition(offset: phone.text.length));
    });
  }

  // The basics go out in both steps; transporter extras ride along on step 2.
  Map<String, dynamic> get _fields => {
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        'country': _iso2(country.value),
        'phone': phone.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
      };

  String _iso2(String? name) =>
      countries.firstWhereOrNull((c) => c.name == name)?.iso2 ?? '';

  Future<void> pickLicense() async => licenseFile.value = await _pickDoc();
  Future<void> pickLegal() async => legalFile.value = await _pickDoc();

  Future<PlatformFile?> _pickDoc() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (res == null || res.files.isEmpty) return null;
    final file = res.files.first;
    if (file.size > 10 * 1024 * 1024) {
      toast('each_document_must_be_10_mb_or_smaller'.tr);
      return null;
    }
    return file;
  }

  Future<void> requestOtp() async {
    if (firstName.text.trim().isEmpty ||
        lastName.text.trim().isEmpty ||
        country.value == null ||
        phone.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.isEmpty) {
      toast('fill_in_all_required_fields'.tr);
      return;
    }
    if (!isValidEmail(email.text)) {
      toast('that_email_address_does_not_look_right'.tr);
      return;
    }
    if (!isValidPassword(password.text)) {
      toast('password_must_be_at_least_8_characters'.tr);
      return;
    }
    if (isTransporter) {
      if (businessName.text.trim().isEmpty || address.text.trim().isEmpty) {
        toast('add_your_legal_name_and_business_address'.tr);
        return;
      }
      if (operatingCountries.isEmpty) {
        toast('pick_at_least_one_country_of_operation'.tr);
        return;
      }
    }
    if (await _sendOtp()) Get.to(() => const OtpPage());
  }

  Future<void> resendOtp() async {
    await _sendOtp();
  }

  Future<bool> _sendOtp() async {
    busy.value = true;
    try {
      await _repo.registerRequestOtp(_fields);
      toast('we_emailed_you_a_verification_code'.tr);
      return true;
    } on AppException catch (e) {
      toastError(e);
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<void> verifyOtp(String otp) async {
    if (otp.trim().isEmpty) {
      toast('enter_the_code_we_emailed_you'.tr);
      return;
    }
    busy.value = true;
    try {
      await _repo.registerVerify(
        _fields,
        otp,
        isTransporter: isTransporter,
        operatingCountries: operatingCountriesIso,
        legalName: businessName.text.trim(),
        address: address.text.trim(),
        transportLicense: licenseFile.value,
        businessDocuments: businessDocuments,
      );
      Get.offAll(() => const MainShell());
    } on AppException catch (e) {
      toastError(e);
    } finally {
      busy.value = false;
    }
  }

  @override
  void onClose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    email.dispose();
    password.dispose();
    businessName.dispose();
    address.dispose();
    super.onClose();
  }
}
