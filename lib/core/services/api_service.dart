import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import '../constants/api_constants.dart';
import '../exceptions/app_exceptions.dart';
import '../utils/notify.dart';
import 'language_service.dart';
import 'session_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  late Dio _dio;

  // set from app.dart — routes back to the welcome screen when a refresh fails
  static void Function()? onSessionExpired;

  factory ApiService() {
    return _instance;
  }

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        headers: ApiConstants.headers,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final session = Get.isRegistered<SessionService>() ? Get.find<SessionService>() : null;
          final token = session?.accessToken;
          // a caller may pin its own bearer (logout cleanup runs with the
          // old token after the session is already cleared)
          if (token != null &&
              token.isNotEmpty &&
              !options.headers.containsKey('Authorization')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // the active UI language wins (priority 1) — server messages + CMS
          // come back localized to it
          options.headers['X-Lang'] = LanguageService.currentCode;
          options.headers['Accept-Language'] = LanguageService.currentCode;
          assert(() {
            if (kDebugMode) {
              print('REQUEST[${options.method}] => PATH: ${options.path}');
            }
            return true;
          }());
          return handler.next(options);
        },
        onResponse: (response, handler) {
          assert(() {
            if (kDebugMode) {
              final body = const JsonEncoder.withIndent('  ').convert(response.data);
              print(
                'RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}\n$body',
              );
            }
            return true;
          }());
          _apiToast(response.requestOptions, response.data, failed: false);
          return handler.next(response);
        },
        onError: (error, handler) async {
          assert(() {
            if (kDebugMode) {
              print(
                'ERROR[${error.response?.statusCode}] => PATH: ${error.requestOptions.path} '
                '=> ${error.response?.data}',
              );
            }
            return true;
          }());

          // expired token: refresh once and replay the request
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/auth/')) {
            final retried = await _refreshAndRetry(error.requestOptions);
            if (retried != null) return handler.resolve(retried);
          }
          _apiToast(error.requestOptions, error.response?.data, failed: true);
          return handler.next(error);
        },
      ),
    );
  }

  // write methods carry a user action worth confirming; GETs load silently
  static const _writeMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};
  // a success toast on every sent message would be noise
  static const _silentSuccess = ['/chats/sendMessage'];
  // background housekeeping the user never asked for — silent either way
  static const _silent = ['/auth/fcm-token'];

  // Surfaces the backend's own `message` for button-driven writes — success in
  // green, failures in red — so every action reports its result app-wide. Only
  // fires when the envelope actually carries a message; bodyless transport
  // errors are left to the screen (which knows the better "no internet" text).
  void _apiToast(RequestOptions req, dynamic body, {required bool failed}) {
    if (!_writeMethods.contains(req.method.toUpperCase())) return;
    if (_silent.any(req.path.contains)) return;
    final msg = body is Map && body['message'] is String ? body['message'] as String : null;
    if (msg == null || msg.trim().isEmpty) return;
    final ok = !failed && body is Map && body['status'] == true;
    if (ok) {
      if (_silentSuccess.any(req.path.contains)) return;
      toastSuccess(msg);
    } else {
      toastError(msg);
    }
  }

  // one refresh at a time: the refresh token rotates, so two parallel 401s
  // refreshing with the same token would make the second one fail and log
  // the user out
  Future<String?>? _refreshing;

  Future<Response?> _refreshAndRetry(RequestOptions failed) async {
    final session = Get.isRegistered<SessionService>() ? Get.find<SessionService>() : null;
    if (session == null || !session.loggedIn) return null;

    // the token may already have been refreshed while this request was out
    final sentWith = failed.headers['Authorization'];
    String? access = session.accessToken;
    if (sentWith == 'Bearer $access') {
      access = await (_refreshing ??= _refresh(session)
        ..whenComplete(() => _refreshing = null));
    }
    if (access == null) return null;
    try {
      failed.headers['Authorization'] = 'Bearer $access';
      return await _dio.fetch(failed);
    } catch (_) {
      return null;
    }
  }

  /// New access token, or null. Only an explicit rejection of the refresh
  /// (401/403) ends the session — no internet, a timeout or a server error
  /// must never log the user out.
  Future<String?> _refresh(SessionService session) async {
    final refresh = session.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      await _expire(session);
      return null;
    }
    try {
      // bare client so a 401 here doesn't loop back into this interceptor;
      // the backend wants both tokens in the body, not a bearer header
      final res = await Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        headers: ApiConstants.headers,
      )).post(
        '/auth/refreshToken',
        data: {'accessToken': session.accessToken, 'refreshToken': refresh},
      );
      final token = res.data?['data']?['token'] ?? res.data?['data'] ?? {};
      final access = token is Map ? token['accessToken'] as String? : null;
      if (access == null) return null;
      await session.setTokens(access, token['refreshToken'] ?? refresh);
      return access;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) await _expire(session);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _expire(SessionService session) async {
    await session.clear();
    onSessionExpired?.call();
  }

  Dio get dio => _dio;

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  /// Sends a POST request to the specified [path].
  ///
  /// Used for creating new resources on the server.
  ///
  /// **Parameters:**
  /// - [path]: API endpoint path
  /// - [data]: Request body data (can be Map, FormData, etc.)
  /// - [queryParameters]: Optional URL query parameters
  /// - [options]: Optional request configuration
  /// - [cancelToken]: Optional token to cancel the request
  ///
  /// **Example:**
  /// ```dart
  /// final response = await apiService.post(
  ///   '/users',
  ///   data: {'name': 'John', 'email': 'john@example.com'},
  /// );
  /// ```
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  /// Sends a PUT request to the specified [path].
  ///
  /// Used for completely replacing an existing resource on the server.
  ///
  /// **Parameters:**
  /// - [path]: API endpoint path
  /// - [data]: Complete resource data to replace existing resource
  /// - [queryParameters]: Optional URL query parameters
  /// - [options]: Optional request configuration
  /// - [cancelToken]: Optional token to cancel the request
  ///
  /// **Example:**
  /// ```dart
  /// final response = await apiService.put(
  ///   '/users/123',
  ///   data: {'name': 'John Doe', 'email': 'john@example.com', 'age': 30},
  /// );
  /// ```
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  /// Sends a PATCH request to the specified [path].
  ///
  /// Used for partially updating an existing resource on the server.
  ///
  /// **Parameters:**
  /// - [path]: API endpoint path
  /// - [data]: Partial resource data containing only fields to update
  /// - [queryParameters]: Optional URL query parameters
  /// - [options]: Optional request configuration
  /// - [cancelToken]: Optional token to cancel the request
  ///
  /// **Example:**
  /// ```dart
  /// final response = await apiService.patch(
  ///   '/users/123',
  ///   data: {'email': 'newemail@example.com'}, // Only updating email
  /// );
  /// ```
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  /// Sends a DELETE request to the specified [path].
  ///
  /// Used for deleting an existing resource from the server.
  ///
  /// **Parameters:**
  /// - [path]: API endpoint path
  /// - [data]: Optional request body data
  /// - [queryParameters]: Optional URL query parameters
  /// - [options]: Optional request configuration
  /// - [cancelToken]: Optional token to cancel the request
  ///
  /// **Example:**
  /// ```dart
  /// final response = await apiService.delete('/users/123');
  /// ```
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  /// Uploads a single file to the specified path
  ///
  /// Example usage:
  /// ```dart
  /// final file = await MultipartFile.fromFile('/path/to/file.jpg');
  /// final response = await _apiService.uploadFile(
  ///   '/api/upload',
  ///   file: file,
  ///   fileName: 'avatar.jpg',
  /// );
  /// ```
  Future<Response> uploadFile(
    String path, {
    required MultipartFile file,
    String fieldName = 'file',
    Map<String, dynamic>? data,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final formData = FormData.fromMap({fieldName: file, ...?data});

      return await _dio.post(
        path,
        data: formData,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  /// Uploads multiple files to the specified path
  ///
  /// Example usage:
  /// ```dart
  /// final files = [
  ///   await MultipartFile.fromFile('/path/to/file1.jpg', filename: 'file1.jpg'),
  ///   await MultipartFile.fromFile('/path/to/file2.jpg', filename: 'file2.jpg'),
  /// ];
  /// final response = await _apiService.uploadMultipleFiles(
  ///   '/api/upload',
  ///   files: files,
  ///   fieldName: 'images',
  /// );
  /// ```
  Future<Response> uploadMultipleFiles(
    String path, {
    required List<MultipartFile> files,
    String fieldName = 'files',
    Map<String, dynamic>? data,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final formData = FormData.fromMap({fieldName: files, ...?data});

      return await _dio.post(
        path,
        data: formData,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  /// Uploads a file with progress tracking
  ///
  /// Example usage:
  /// ```dart
  /// final file = await MultipartFile.fromFile('/path/to/file.jpg');
  /// final response = await _apiService.uploadFileWithProgress(
  ///   '/api/upload',
  ///   file: file,
  ///   onSendProgress: (int sent, int total) {
  ///     double progress = (sent / total) * 100;
  ///     print('Upload progress: $progress%');
  ///   },
  /// );
  /// ```
  Future<Response> uploadFileWithProgress(
    String path, {
    required MultipartFile file,
    String fieldName = 'file',
    Map<String, dynamic>? data,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({fieldName: file, ...?data});

      return await _dio.post(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw UnknownException(e.toString());
    }
  }

  /// Converts DioException to typed AppException for better error handling.
  ///
  /// This method maps Dio's generic exceptions to our custom exception types,
  /// allowing for more specific error handling in the UI layer.
  ///
  /// **Mapping:**
  /// - Connection/Send/Receive Timeout → [TimeoutException]
  /// - Connection Error → [NoInternetException]
  /// - Bad Response (4xx, 5xx) → [ServerException]
  /// - Request Cancelled → [UnknownException]
  /// - Bad Certificate → [ServerException]
  /// - Socket Exception → [NoInternetException]
  /// - Other Unknown Errors → [UnknownException]
  ///
  /// **Example:**
  /// ```dart
  /// try {
  ///   await dio.get('/api/data');
  /// } on DioException catch (e) {
  ///   throw _handleDioError(e); // Converts to typed exception
  /// }
  /// ```
  AppException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutException(error.message);

      case DioExceptionType.connectionError:
        return NoInternetException(error.message);

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        // the backend puts the human-readable reason in the envelope
        final body = error.response?.data;
        final message = (body is Map ? body['message'] : null) ??
            error.response?.statusMessage ??
            'server_error'.tr;
        return ServerException(message, statusCode, error.message);

      case DioExceptionType.cancel:
        return UnknownException('request_cancelled'.tr);

      case DioExceptionType.badCertificate:
        return ServerException('secure_connection_failed'.tr, null, error.message);

      case DioExceptionType.unknown:
        if (error.message?.contains('SocketException') ?? false) {
          return NoInternetException(error.message);
        }
        return UnknownException(error.message);
    }
  }

  void dispose() {
    _dio.close();
  }
}
