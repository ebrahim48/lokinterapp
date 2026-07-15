import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/utils/notify.dart';
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

  // license + legal docs both go into businessDocuments[] (backend accepts up to 5)
  List<PlatformFile> get documents =>
      [licenseFile.value, legalFile.value].whereType<PlatformFile>().toList();

  @override
  void onInit() {
    super.onInit();
    _lookups.countries().then(countries.assignAll).catchError((_) {});
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
      toast('Each document must be 10 MB or smaller');
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
      toast('Fill in all required fields');
      return;
    }
    if (isTransporter && operatingCountries.isEmpty) {
      toast('Pick at least one country of operation');
      return;
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
      toast('We emailed you a verification code');
      return true;
    } on AppException catch (e) {
      toastError(e);
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<void> verifyOtp(String otp) async {
    busy.value = true;
    try {
      await _repo.registerVerify(
        _fields,
        otp,
        isTransporter: isTransporter,
        operatingCountries: operatingCountriesIso,
        documents: documents,
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
