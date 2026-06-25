import 'package:dio/dio.dart';
import 'constants.dart';
import 'secure_storage.dart';

class DioClient {
  static Dio? _instance;

  static Dio get instance {
    _instance ??= _create();
    return _instance!;
  }

  static Dio _create() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    dio.interceptors.add(_JwtInterceptor(dio));
    return dio;
  }
}

class _JwtInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  _JwtInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await SecureStorage.getRefreshToken();
        if (refreshToken == null) {
          await SecureStorage.clearAll();
          handler.next(err);
          return;
        }

        // Create a fresh Dio to avoid interceptor loop
        final refreshDio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
        final response = await refreshDio.post(
          '/api/auth/token/refresh/',
          data: {'refresh': refreshToken},
        );

        final newAccess = response.data['access'] as String;
        final newRefresh = response.data['refresh'] as String? ?? refreshToken;
        await SecureStorage.saveTokens(access: newAccess, refresh: newRefresh);

        // Retry original request
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        final retried = await _dio.fetch(err.requestOptions);
        handler.resolve(retried);
      } catch (_) {
        await SecureStorage.clearAll();
        handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    } else {
      handler.next(err);
    }
  }
}

// Helper to extract API errors cleanly
String extractError(DioException e) {
  try {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'];
    if (data is Map && data['detail'] != null) return data['detail'].toString();
  } catch (_) {}
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return 'Connection timed out. Please try again.';
  }
  if (e.type == DioExceptionType.connectionError) {
    return 'No internet connection.';
  }
  return 'Something went wrong. Please try again.';
}
