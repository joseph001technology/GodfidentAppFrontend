import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'constants.dart';
import 'secure_storage.dart';
import 'auth_event_service.dart';

class DioClient {
  static Dio? _instance;
  static _JwtInterceptor? _jwt;

  /// Optional callback invoked when auth is considered expired (401 + unable to refresh).
  /// Set this from app-level code to perform logout/navigation/UI actions.
  static void Function()? onAuthExpired;

  static Dio get instance {
    _instance ??= _create();
    return _instance!;
  }

  static Dio _create() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      // The backend is on a free Render instance that can take ~30-50s to
      // wake up, so keep these generous.
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));
    _jwt = _JwtInterceptor(dio);
    dio.interceptors.add(_jwt!);
    return dio;
  }

  /// Keeps the login alive while the app is used. Call it on start, on resume
  /// and on a timer: if the access token is about to expire it is renewed
  /// (sliding session - the refresh token is renewed too, so active use never
  /// logs you out).
  ///
  ///  true  -> signed in with a valid token
  ///  false -> no session, or the server rejected it: the user has been signed out
  ///  null  -> couldn't reach the server; keep the session and try again later
  static Future<bool?> ensureSession({Duration renewWithin = const Duration(minutes: 10)}) async {
    final access = await SecureStorage.getAccessToken();
    if (access == null || access.isEmpty) return false;
    final exp = _expiry(access);
    if (exp != null && exp.difference(DateTime.now()).compareTo(renewWithin) > 0) return true;

    instance; // make sure the interceptor exists
    final r = await _jwt!.refreshShared();
    if (r.access != null) return true;
    if (r.rejected) {
      try {
        onAuthExpired?.call();
      } catch (_) {}
      AuthEventService().notifyUnauthorized();
      return false;
    }
    return null;
  }

  static DateTime? _expiry(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map;
      final exp = payload['exp'];
      return exp is num ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000) : null;
    } catch (_) {
      return null;
    }
  }
}

/// Endpoints that must never carry an Authorization header. Sending a stale
/// token to these makes DRF's JWTAuthentication answer 401 even though the
/// endpoint itself needs no login (and a wrong password on /login/ is a real
/// 401 that must reach the UI untouched, not trigger a refresh attempt).
const _noAuthPaths = <String>[
  '/api/auth/login/',
  '/api/auth/register/',
  '/api/auth/token/refresh/',
  '/api/auth/forgot-password/',
  '/api/auth/reset-password/',
  '/api/auth/verify-email/',
];

bool _isNoAuthPath(String path) => _noAuthPaths.any(path.contains);

class _RefreshResult {
  final String? access;

  /// true  => the server definitively rejected the refresh token (session over)
  /// false => we simply couldn't reach the server (offline / timeout); the
  ///          stored session may still be perfectly valid.
  final bool rejected;
  const _RefreshResult(this.access, {this.rejected = false});
}

class _JwtInterceptor extends Interceptor {
  final Dio _dio;

  /// One refresh at a time. Every request that gets a 401 while a refresh is
  /// running awaits THIS future instead of failing straight through to the UI
  /// (the old code returned the raw 401 to every concurrent request, which is
  /// exactly what the Bible screen does: it fires several requests at once).
  Future<_RefreshResult>? _refreshing;

  _JwtInterceptor(this._dio);

  Future<_RefreshResult> refreshShared() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isNoAuthPath(options.path) && options.extra['skipAuth'] != true) {
      final token = await SecureStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    if (!is401 || _isNoAuthPath(req.path) || req.extra['retried'] == true) {
      handler.next(err);
      return;
    }

    // Nothing stored => the user simply isn't signed in. Don't treat that as
    // an expired session; just let the 401 through (public endpoints are
    // handled below).
    final hadToken = (await SecureStorage.getAccessToken()) != null;

    final result = await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null));

    if (result.access != null) {
      req.headers['Authorization'] = 'Bearer ${result.access}';
      req.extra['retried'] = true;
      try {
        handler.resolve(await _dio.fetch(req));
      } on DioException catch (e) {
        handler.next(e);
      }
      return;
    }

    if (!result.rejected) {
      // Offline / server asleep: keep the session, surface the original error.
      handler.next(err);
      return;
    }

    // Session is genuinely dead.
    if (hadToken) {
      try {
        DioClient.onAuthExpired?.call();
      } catch (_) {}
      AuthEventService().notifyUnauthorized();
    }

    // Public endpoints (Bible books/translations) work without a token, so
    // retry once WITHOUT Authorization rather than failing a request that
    // never needed login in the first place.
    req.headers.remove('Authorization');
    req.extra['retried'] = true;
    req.extra['skipAuth'] = true;
    try {
      handler.resolve(await _dio.fetch(req));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<_RefreshResult> _refresh() async {
    final refreshToken = await SecureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await SecureStorage.clearAll();
      return const _RefreshResult(null, rejected: true);
    }
    try {
      // Fresh Dio so this call can't re-enter the interceptor.
      final refreshDio = Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 60),
      ));
      final response = await refreshDio.post(
        '/api/auth/token/refresh/',
        data: {'refresh': refreshToken},
      );
      final newAccess = response.data['access'] as String;
      final newRefresh = response.data['refresh'] as String? ?? refreshToken;
      await SecureStorage.saveTokens(access: newAccess, refresh: newRefresh);
      return _RefreshResult(newAccess);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 400 || code == 401 || code == 403) {
        await SecureStorage.clearAll();
        return const _RefreshResult(null, rejected: true);
      }
      return const _RefreshResult(null); // network / 5xx: keep the session
    } catch (_) {
      return const _RefreshResult(null);
    }
  }
}

/// Extracts the backend's own message when there is one.
String extractError(DioException e) {
  try {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is Map && data['detail'] != null) return data['detail'].toString();
  } catch (_) {}
  return friendlyError(e);
}

/// User-facing text for ANY error object. Never shows raw exception text
/// (e.g. "DioException [bad response]: ... status code of 401 ...").
String friendlyError(Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The server took too long to respond. It may be waking up — please try again in a moment.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network and try again.';
      default:
        break;
    }
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? serverMsg;
    if (data is Map) {
      serverMsg = (data['message'] ?? data['detail'])?.toString();
    }
    if (status == 401) {
      return 'Your session has expired. Please sign in again.';
    }
    if (status == 403) return 'You don\'t have permission to do that.';
    if (status == 404) return serverMsg ?? 'That content could not be found.';
    if (status == 429) return 'Too many requests. Please wait a moment and try again.';
    if (status != null && status >= 500) {
      return 'The server had a problem (error $status). Please try again shortly.';
    }
    if (serverMsg != null && serverMsg.isNotEmpty) return serverMsg;
    // Django REST validation errors look like {"date": ["Date has wrong format."]}
    if (data is Map) {
      final field = _firstFieldError(data);
      if (field != null) return field;
    }
    if (status != null) return 'The server rejected that request (error $status). Please check the details and try again.';
  }
  if (e is! DioException) {
    // Not a network error: a bug on the phone. Say what it was.
    return 'Something went wrong on this phone (${e.runtimeType}). Please try again.';
  }
  return 'Something went wrong. Please try again.';
}

String? _firstFieldError(Map data) {
  for (final entry in data.entries) {
    final k = entry.key.toString();
    if (k == 'success') continue;
    final v = entry.value;
    String? msg;
    if (v is List && v.isNotEmpty) {
      msg = v.first.toString();
    } else if (v is String && v.isNotEmpty) {
      msg = v;
    } else if (v is Map) {
      msg = _firstFieldError(v);
    }
    if (msg != null) {
      if (k == 'non_field_errors' || k == 'errors' || k == 'detail' || k == 'data') return msg;
      final label = k.replaceAll('_', ' ');
      return '${label[0].toUpperCase()}${label.substring(1)}: $msg';
    }
  }
  return null;
}
