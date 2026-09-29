import 'dart:async';

import 'package:dio/dio.dart';

import '../constants/api_paths.dart';
import '../logging/app_logger.dart';
import '../network/api_error_dto.dart';
import '../network/token_store.dart';

typedef SessionExpiredCallback = void Function();
typedef AccountSuspendedCallback = void Function();

/// Centralized 401 refresh. One in-flight refresh, queued retries, no loops.
/// Does not refresh on suspended/deleted/business auth failures.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio refreshClient,
    required TokenStore tokenStore,
    required AppLogger logger,
    this.onSessionExpired,
    this.onAccountSuspended,
  }) : _refreshClient = refreshClient,
       _tokenStore = tokenStore,
       _logger = logger;

  final Dio _refreshClient;
  final TokenStore _tokenStore;
  final AppLogger _logger;
  final SessionExpiredCallback? onSessionExpired;
  final AccountSuspendedCallback? onAccountSuspended;

  Completer<String?>? _refreshCompleter;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isAuthPath(options.path) && options.method != 'GET') {
      handler.next(options);
      return;
    }
    final token = await _tokenStore.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final code = _errorCode(err);
    if (code == 'ACCOUNT_SUSPENDED' || code == 'USER_SUSPENDED') {
      await _tokenStore.clear();
      onAccountSuspended?.call();
      handler.next(err);
      return;
    }
    if (code == 'ACCOUNT_DELETED' ||
        code == 'AUTH_REFRESH_REUSED' ||
        code == 'AUTH_SESSION_REVOKED') {
      await _failSession(err, handler);
      return;
    }

    if (!_shouldRefresh(err)) {
      handler.next(err);
      return;
    }

    try {
      final accessToken = await _refreshAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        await _failSession(err, handler);
        return;
      }

      final request = err.requestOptions;
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.extra['retried'] = true;
      final response = await _refreshClient.fetch<dynamic>(request);
      handler.resolve(response);
    } on Object catch (error, stackTrace) {
      _logger.error(
        'Token refresh failed',
        feature: 'auth',
        error: error,
        stackTrace: stackTrace,
      );
      await _failSession(err, handler);
    }
  }

  bool _shouldRefresh(DioException err) {
    if (err.response?.statusCode != 401) {
      return false;
    }
    if (err.requestOptions.extra['retried'] == true) {
      return false;
    }
    if (_isAuthPath(err.requestOptions.path)) {
      return false;
    }
    final code = _errorCode(err);
    // Only refresh expired/missing access token — not business 401s.
    if (code == 'INVALID_CREDENTIALS' ||
        code == 'OTP_INVALID' ||
        code == 'OTP_EXPIRED' ||
        code == 'ACCOUNT_DELETED') {
      return false;
    }
    return code == null ||
        code == 'UNAUTHENTICATED' ||
        code == 'UNAUTHORIZED' ||
        code == 'AUTH_INVALID_SESSION';
  }

  String? _errorCode(DioException err) {
    final data = err.response?.data;
    if (data is Map<String, dynamic>) {
      return ApiErrorDto.fromJson(data).code;
    }
    return null;
  }

  bool _isAuthPath(String path) {
    return path.contains(ApiPaths.authLogin) ||
        path.contains(ApiPaths.authRegister) ||
        path.contains(ApiPaths.authRefresh) ||
        path.contains(ApiPaths.authLogout) ||
        path.contains(ApiPaths.authOtpRequest) ||
        path.contains(ApiPaths.authOtpVerify) ||
        path.contains(ApiPaths.authPhoneOtpRequest) ||
        path.contains(ApiPaths.authPhoneOtpVerify);
  }

  Future<String?> _refreshAccessToken() async {
    final inFlight = _refreshCompleter;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await _tokenStore.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(null);
        return null;
      }

      final response = await _refreshClient.post<Map<String, dynamic>>(
        ApiPaths.authRefresh,
        data: {'refreshToken': refreshToken},
      );
      final data = response.data ?? const <String, dynamic>{};
      final access = data['accessToken'] as String?;
      final refresh = data['refreshToken'] as String?;
      if (access == null || refresh == null) {
        completer.complete(null);
        return null;
      }
      await _tokenStore.writeTokens(accessToken: access, refreshToken: refresh);
      completer.complete(access);
      return access;
    } on Object {
      completer.complete(null);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> _failSession(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    await _tokenStore.clear();
    onSessionExpired?.call();
    handler.next(err);
  }
}
