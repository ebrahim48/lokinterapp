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
    List<PlatformFile> documents = const [],
  }) async {
    dynamic body;
    // files force multipart; the array fields switch to bracket-indexed keys
    if (documents.isNotEmpty) {
      final map = <String, dynamic>{
        'step': 2,
        ...fields,
        'otp': otp,
        'isTransporter': isTransporter ? 1 : 0,
        for (var i = 0; i < operatingCountries.length; i++)
          'operatingCountries[$i]': operatingCountries[i],
      };
      for (var i = 0; i < documents.length; i++) {
        final f = documents[i];
        if (f.path != null) {
          map['businessDocuments[$i]'] =
              await MultipartFile.fromFile(f.path!, filename: f.name);
        }
      }
      body = FormData.fromMap(map);
    } else {
      body = {
        'step': 2,
        ...fields,
        'otp': otp,
        'isTransporter': isTransporter,
        if (operatingCountries.isNotEmpty) 'operatingCountries': operatingCountries,
      };
    }
    final res = await _api.post('/auth/register', data: body);
    await _session.saveLogin(Map<String, dynamic>.from(unwrapData(res)));
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

  Future<void> changePassword(String current, String next) async {
    unwrapData(await _api.post('/auth/changePassword', data: {
      'currentPassword': current,
      'password': next,
      'passwordConfirmation': next,
    }));
  }
}
