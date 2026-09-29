import 'package:dio/dio.dart';

import '../logging/app_logger.dart';

class LoggingInterceptor extends Interceptor {
  LoggingInterceptor(this._logger);

  final AppLogger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final started = DateTime.now();
    options.extra['startedAt'] = started;
    _logger.debug(
      'HTTP request',
      feature: 'network',
      data: {
        'method': options.method,
        'path': options.uri.path,
        'requestId': options.headers['x-request-id'],
      },
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final started = response.requestOptions.extra['startedAt'];
    final durationMs = started is DateTime
        ? DateTime.now().difference(started).inMilliseconds
        : null;
    _logger.debug(
      'HTTP response',
      feature: 'network',
      data: {
        'method': response.requestOptions.method,
        'path': response.requestOptions.uri.path,
        'status': response.statusCode,
        'durationMs': durationMs,
        'requestId': response.requestOptions.headers['x-request-id'],
      },
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.warning(
      'HTTP error',
      feature: 'network',
      data: {
        'method': err.requestOptions.method,
        'path': err.requestOptions.uri.path,
        'host': err.requestOptions.uri.host,
        'status': err.response?.statusCode,
        'type': err.type.name,
        'requestId': err.requestOptions.headers['x-request-id'],
      },
    );
    handler.next(err);
  }
}
