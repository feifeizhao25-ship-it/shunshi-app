import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/token_storage.dart';

/// Authenticated HTTP client shared by all ShunShi screens.
class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? _createDio() {
    if (dio == null && adapterOverride != null) {
      _dio.httpClientAdapter = adapterOverride!();
    }
  }

  static String get baseUrl => AppConfig.apiBaseUrl;

  @visibleForTesting
  static HttpClientAdapter Function()? adapterOverride;

  final Dio _dio;

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.addAll([
      _AuthInterceptor(),
      _RetryInterceptor(dio),
      if (kDebugMode) _SafeLoggingInterceptor(),
    ]);
    return dio;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _dio.post<T>(
    path,
    data: data,
    queryParameters: queryParameters,
    options: options,
  );

  Future<Response<T>> put<T>(String path, {Object? data, Options? options}) =>
      _dio.put<T>(path, data: data, options: options);

  Future<Response<T>> patch<T>(String path, {Object? data, Options? options}) =>
      _dio.patch<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Options? options,
  }) => _dio.delete<T>(path, data: data, options: options);
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  static const _maxRetries = 2;
  final Dio _dio;

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final retries = request.extra['shunshiRetries'] as int? ?? 0;
    final methodIsIdempotent = {
      'GET',
      'HEAD',
      'OPTIONS',
    }.contains(request.method);
    final transient =
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        (error.response?.statusCode ?? 0) >= 500;

    if (methodIsIdempotent && transient && retries < _maxRetries) {
      request.extra['shunshiRetries'] = retries + 1;
      await Future<void>.delayed(Duration(milliseconds: 400 * (retries + 1)));
      try {
        handler.resolve(await _dio.fetch<dynamic>(request));
        return;
      } on DioException {
        // Preserve the original error after the bounded retry fails.
      }
    }
    handler.next(error);
  }
}

class _SafeLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[API] ${options.method} ${options.uri.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[API] ${response.statusCode} ${response.requestOptions.uri.path}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    debugPrint(
      '[API] ${error.response?.statusCode ?? 'network'} '
      '${error.requestOptions.uri.path}',
    );
    handler.next(error);
  }
}
