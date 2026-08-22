// Network Service
// Handles API requests with retry, offline detection, and error handling

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';
import '../storage/local_storage.dart';

/// API 根地址，统一由 AppConfig 提供。
///
/// AppConfig 在 release 构建下会强制要求通过 `--dart-define=SHUNSHI_API_BASE_URL=...`
/// 注入真实地址，避免打包后请求打向设备本机。
String get _apiBaseUrl => '${AppConfig.apiBaseUrl}/api/v1';

enum NetworkStatus {
  online,
  offline,
  unknown,
}

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  
  late final Dio _dio;
  final Connectivity _connectivity = Connectivity();
  
  // Network status stream
  final _statusController = StreamController<NetworkStatus>.broadcast();
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  /// 登录态失效广播。
  ///
  /// token 刷新失败时清了本地令牌，但此前没有任何机制告诉 UI ——
  /// 用户会停在一个看似已登录、实则每个请求都 401 的界面上。
  /// 上层订阅本流后应跳转登录页。
  final _unauthorizedController = StreamController<void>.broadcast();
  Stream<void> get unauthorizedStream => _unauthorizedController.stream;

  void notifyUnauthorized() {
    if (!_unauthorizedController.isClosed) {
      _unauthorizedController.add(null);
    }
  }
  
  NetworkStatus _currentStatus = NetworkStatus.unknown;
  NetworkStatus get currentStatus => _currentStatus;
  
  NetworkService._internal() {
    _dio = _createDio();
    _initConnectivity();
  }
  
  Dio get client => _dio;
  
  Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: _apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // Add interceptors
    dio.interceptors.addAll([
      _AuthInterceptor(),
      _RetryInterceptor(),
      _OfflineInterceptor(),
      // 请求日志只在调试构建开启 —— release 包里逐条打印
      // API 路径会泄露用户行为轨迹。
      if (kDebugMode) _LoggingInterceptor(),
    ]);
    
    return dio;
  }
  
  void _initConnectivity() {
    _connectivity.onConnectivityChanged.listen((results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _currentStatus = result == ConnectivityResult.none 
          ? NetworkStatus.offline 
          : NetworkStatus.online;
      _statusController.add(_currentStatus);
    });
    
    // Check initial status
    _connectivity.checkConnectivity().then((results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _currentStatus = result == ConnectivityResult.none 
          ? NetworkStatus.offline 
          : NetworkStatus.online;
      _statusController.add(_currentStatus);
    });
  }
  
  // Check if online
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    return result != ConnectivityResult.none;
  }
  
  // Force refresh connectivity status
  Future<void> refreshStatus() async {
    final results = await _connectivity.checkConnectivity();
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _currentStatus = result == ConnectivityResult.none 
        ? NetworkStatus.offline 
        : NetworkStatus.online;
    _statusController.add(_currentStatus);
  }
  
  void dispose() {
    _statusController.close();
    _unauthorizedController.close();
  }
}

// ==================== Auth Interceptor ====================

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Add auth token if available
    final token = await tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
  
  /// 刷新接口自身返回的 401 不能再触发刷新，否则会无限递归。
  static bool _isRefreshCall(RequestOptions options) =>
      options.path.contains('/auth/refresh');

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshCall(err.requestOptions)) {
      // Token expired, try to refresh
      final refreshed = await tokenStorage.refreshToken((refreshToken) async {
        // 刷新请求用**干净的** Dio：不带 _AuthInterceptor，
        // 否则它会给刷新请求也塞上已过期的 Authorization 头，
        // 并在刷新本身 401 时再次进入本分支。
        final dio = Dio();
        final response = await dio.post(
          '$_apiBaseUrl/auth/refresh',
          data: {'refresh_token': refreshToken},
        );
        // 原来写的是 `as Map<String, String>` —— JSON 解出来是
        // Map<String, dynamic>，这个转换**必然抛 TypeError**，
        // 被 refreshToken 的 catch 吞掉后一律当刷新失败。
        // 也就是说自动续期从来没成功过。
        return Map<String, dynamic>.from(response.data as Map);
      });

      if (refreshed) {
        // Retry the original request
        try {
          final token = await tokenStorage.getAccessToken();
          err.requestOptions.headers['Authorization'] = 'Bearer $token';

          final dio = Dio();
          final response = await dio.fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          return handler.next(err);
        }
      } else {
        // 刷新失败：清 token 之外还要广播登出。
        // 原实现只 clearTokens()，UI 层无从知晓 —— 用户会停在一个
        // 看似已登录、但每个请求都 401 的界面上，只能靠杀进程恢复。
        await tokenStorage.clearTokens();
        NetworkService().notifyUnauthorized();
      }
    }
    handler.next(err);
  }
}

// ==================== Retry Interceptor ====================

class _RetryInterceptor extends Interceptor {
  static const _maxRetries = 3;
  static const _retryDelay = Duration(seconds: 1);
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final retryCount = options.extra['retryCount'] ?? 0;
    
    // Only retry on network errors or 5xx errors
    final shouldRetry = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode ?? 0) >= 500;
    
    if (shouldRetry && retryCount < _maxRetries) {
      // Wait before retrying
      await Future.delayed(_retryDelay * (retryCount + 1));
      
      // Update retry count
      options.extra['retryCount'] = retryCount + 1;
      
      try {
        final dio = Dio();
        final response = await dio.fetch(options);
        return handler.resolve(response);
      } catch (e) {
        return handler.next(err);
      }
    }
    
    handler.next(err);
  }
}

// ==================== Offline Interceptor ====================

class _OfflineInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final networkService = NetworkService();
    final isOnline = await networkService.isOnline();
    
    if (!isOnline && options.extra['offlineMode'] != 'disabled') {
      // Check if request supports offline
      if (options.extra['offlineQueue'] == true) {
        // Queue the request for later
        await localStorage.addToOfflineQueue({
          'method': options.method,
          'path': options.path,
          'data': options.data,
          'queryParams': options.queryParameters,
          'requestId': options.hashCode.toString(),
        });
        
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: 'Request queued for offline sync',
          ),
          true,
        );
      }
    }
    
    handler.next(options);
  }
}

// ==================== Logging Interceptor ====================

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('📤 [API] ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('📥 [API] ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('❌ [API] ${err.response?.statusCode} ${err.requestOptions.path}');
    handler.next(err);
  }
}

// Global instance
final networkService = NetworkService();
