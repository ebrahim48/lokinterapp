import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;
import '../../../core/services/api_envelope.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/session_service.dart';
import 'models/auth_user.dart';

class AuthRepository {
  final _api = Get.find<ApiService>();
  final _session = Get.find<SessionService>();

  Future<void> login(String email, String password) async {
    final res = await _api.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await _session.saveLogin(Map<String, dynamic>.from(unwrapData(res)));
  }

  // step 1 sends the OTP to the email, step 2 creates the account
  Future<void> registerRequestOtp(Map<String, dynamic> fields) async {
    final res = await _api.post('/auth/register', data: {'step': 1, ...fields});
    unwrapData(res);
  }

  Future<void> registerVerify(
    Map<String, dynamic> fields,
    String otp, {
    bool isTransporter = false,
    List<String> operatingCountries = const [],
    String? legalName,
    String? address,
    PlatformFile? transportLicense,
    List<PlatformFile> businessDocuments = const [],
  }) async {
    final dynamic body = isTransporter
        ? await transporterStep2(
            fields: fields,
            otp: otp,
            operatingCountries: operatingCountries,
            legalName: legalName,
            address: address,
            transportLicense: transportLicense,
            businessDocuments: businessDocuments,
          )
        : {'step': 2, ...fields, 'otp': otp, 'isTransporter': false};
    final res = await _api.post('/auth/register', data: body);
    await _session.saveLogin(Map<String, dynamic>.from(unwrapData(res)));
  }

  // Step-2 transporter multipart body. Multipart so the license/legal docs ride
  // along; operatingCountries goes as a JSON string and isTransporter as the
  // text "true", per the API spec. Static + pure so the payload is testable.
  static Future<FormData> transporterStep2({
    required Map<String, dynamic> fields,
    required String otp,
    List<String> operatingCountries = const [],
    String? legalName,
    String? address,
    PlatformFile? transportLicense,
    List<PlatformFile> businessDocuments = const [],
  }) async {
    final map = <String, dynamic>{
      'step': 2,
      ...fields,
      'otp': otp,
      'isTransporter': 'true',
      if (operatingCountries.isNotEmpty) 'operatingCountries': jsonEncode(operatingCountries),
      if (legalName != null && legalName.trim().isNotEmpty) 'legalName': legalName.trim(),
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
    };
    if (transportLicense?.path != null) {
      map['transportLicense'] =
          await MultipartFile.fromFile(transportLicense!.path!, filename: transportLicense.name);
    }
    for (var i = 0; i < businessDocuments.length; i++) {
      final f = businessDocuments[i];
      if (f.path != null) {
        map['businessDocuments[$i]'] =
            await MultipartFile.fromFile(f.path!, filename: f.name);
      }
    }
    return FormData.fromMap(map);
  }

  Future<AuthUser> me() async {
    final res = await _api.get('/auth/user');
    final data = Map<String, dynamic>.from(unwrapData(res));
    final user = AuthUser.fromJson(data);
    await _session.saveUser(user);
    // this endpoint rotates the token pair on every call — keep the fresh one
    final token = data['token'];
    if (token is Map && token['accessToken'] != null) {
      await _session.setTokens(token['accessToken'], token['refreshToken']);
    }
    return user;
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // token may already be dead — clear locally either way
    }
    await _session.clear();
  }

  Future<void> forgotPassword(String email) async {
    unwrapData(await _api.post('/auth/forgotPassword', data: {'email': email}));
  }

  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
  }) async {
    unwrapData(await _api.post('/auth/resetPassword', data: {
      'token': token,
      'email': email,
      'password': password,
      'passwordConfirmation': password,
    }));
  }

  // NB: this endpoint's field names differ from resetPassword — it wants
  // newPassword/confirmPassword (matches the website's authApi payload).
  Future<void> changePassword(String current, String next) async {
    unwrapData(await _api.post('/auth/changePassword', data: {
      'currentPassword': current,
      'newPassword': next,
      'confirmPassword': next,
    }));
  }
}
