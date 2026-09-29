import 'package:dio/dio.dart';

import '../../app/config/app_config.dart';
import '../errors/app_failure.dart';
import '../errors/error_mapper.dart';
import '../logging/app_logger.dart';
import '../utils/result.dart';
import 'auth_interceptor.dart';
import 'logging_interceptor.dart';
import 'request_id_interceptor.dart';
import 'token_store.dart';

class ApiClient {
  ApiClient({
    required AppConfig config,
    required TokenStore tokenStore,
    required AppLogger logger,
    SessionExpiredCallback? onSessionExpired,
    AccountSuspendedCallback? onAccountSuspended,
    Dio? dio,
    Dio? refreshDio,
  }) : _logger = logger {
    final baseOptions = BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      sendTimeout: config.connectTimeout,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    _refreshDio = refreshDio ?? Dio(baseOptions);
    _refreshDio.interceptors.addAll([
      RequestIdInterceptor(),
      LoggingInterceptor(logger),
    ]);

    _dio = dio ?? Dio(baseOptions);
    _dio.interceptors.addAll([
      RequestIdInterceptor(),
      AuthInterceptor(
        refreshClient: _refreshDio,
        tokenStore: tokenStore,
        logger: logger,
        onSessionExpired: onSessionExpired,
        onAccountSuspended: onAccountSuspended,
      ),
      LoggingInterceptor(logger),
    ]);
  }

  late final Dio _dio;
  late final Dio _refreshDio;
  final AppLogger _logger;

  Dio get raw => _dio;

  Future<Result<T>> get<T>(
    String path, {
    required T Function(dynamic data) parser,
    Map<String, dynamic>? query,
  }) {
    return _guard(
      () => _dio.get<dynamic>(path, queryParameters: query),
      parser,
    );
  }

  Future<Result<T>> post<T>(
    String path, {
    required T Function(dynamic data) parser,
    Object? body,
  }) {
    return _guard(() => _dio.post<dynamic>(path, data: body), parser);
  }

  Future<Result<T>> patch<T>(
    String path, {
    required T Function(dynamic data) parser,
    Object? body,
  }) {
    return _guard(() => _dio.patch<dynamic>(path, data: body), parser);
  }

  Future<Result<T>> delete<T>(
    String path, {
    required T Function(dynamic data) parser,
  }) {
    return _guard(() => _dio.delete<dynamic>(path), parser);
  }

  Future<Result<T>> _guard<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic data) parser,
  ) async {
    try {
      final response = await request();
      return Success(parser(response.data));
    } on DioException catch (error, stackTrace) {
      final failure = ErrorMapper.fromDio(error);
      _logger.warning(
        'API mapped failure',
        feature: 'network',
        data: {
          'kind': failure.kind.name,
          'code': failure.code,
          'status': failure.statusCode,
          'requestId': failure.requestId,
        },
      );
      if (failure.kind == FailureKind.server) {
        _logger.error(
          'API server failure',
          feature: 'network',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return Failure(failure);
    } on Object catch (error, stackTrace) {
      _logger.error(
        'Unexpected API error',
        feature: 'network',
        error: error,
        stackTrace: stackTrace,
      );
      return const Failure(
        AppFailure(
          kind: FailureKind.unknown,
          message: 'Something went wrong. Please try again.',
          code: 'INTERNAL',
        ),
      );
    }
  }
}
