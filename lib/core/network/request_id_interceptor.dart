import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor({Uuid uuid = const Uuid()}) : _uuid = uuid;

  final Uuid _uuid;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['x-request-id'] ??= _uuid.v4();
    handler.next(options);
  }
}
