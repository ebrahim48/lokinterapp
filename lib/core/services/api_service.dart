import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import '../constants/api_constants.dart';
import '../exceptions/app_exceptions.dart';
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
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
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
              print(
                'RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}',
              );
            }
            return true;
          }());
          return handler.next(response);
        },
        onError: (error, handler) async {
          assert(() {
            if (kDebugMode) {
              print(
                'ERROR[${error.response?.statusCode}] => PATH: ${error.requestOptions.path}',
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
          return handler.next(error);
        },
      ),
    );
  }

  Future<Response?> _refreshAndRetry(RequestOptions failed) async {
    final session = Get.isRegistered<SessionService>() ? Get.find<SessionService>() : null;
    final refresh = session?.refreshToken;
    if (session == null || refresh == null || refresh.isEmpty) return null;

    try {
      // bare client so a 401 here doesn't loop back into this interceptor;
      // the backend wants both tokens in the body, not a bearer header
      final res = await Dio(BaseOptions(baseUrl: ApiConstants.baseUrl)).post(
        '/auth/refreshToken',
        data: {'accessToken': session.accessToken, 'refreshToken': refresh},
      );
      final token = res.data?['data']?['token'] ?? res.data?['data'] ?? {};
      final access = token['accessToken'] as String?;
      if (access == null) throw Exception('no token in refresh response');
      await session.setTokens(access, token['refreshToken'] ?? refresh);

      failed.headers['Authorization'] = 'Bearer $access';
      return await _dio.fetch(failed);
    } catch (_) {
      await session.clear();
      onSessionExpired?.call();
      return null;
    }
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
  }) async {
    try {
      return await _dio.post(
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
            'Server error';
        return ServerException(message, statusCode, error.message);

      case DioExceptionType.cancel:
        return UnknownException('Request cancelled');

      case DioExceptionType.badCertificate:
        return ServerException('Bad certificate', null, error.message);

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
