import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/core/constants/api_paths.dart';
import 'package:gmatez_app/core/logging/app_logger.dart';
import 'package:gmatez_app/core/network/auth_interceptor.dart';
import 'package:gmatez_app/core/network/token_store.dart';

class _MemoryTokenStore implements TokenStore {
  String? access;
  String? refresh;

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }
}

class _CaptureHandler extends RequestInterceptorHandler {
  _CaptureHandler(this.out);
  final List<RequestOptions> out;

  @override
  void next(RequestOptions requestOptions) {
    out.add(requestOptions);
  }
}

void main() {
  late AuthInterceptor interceptor;
  late _MemoryTokenStore store;

  setUp(() {
    store = _MemoryTokenStore()..access = 'stale-access';
    interceptor = AuthInterceptor(
      refreshClient: Dio(),
      tokenStore: store,
      logger: AppLogger(enabled: false),
    );
  });

  test('phone OTP request does not attach stale Bearer', () async {
    final out = <RequestOptions>[];
    await interceptor.onRequest(
      RequestOptions(path: ApiPaths.authPhoneOtpRequest, method: 'POST'),
      _CaptureHandler(out),
    );
    expect(out.single.headers['Authorization'], isNull);
  });

  test('phone OTP verify does not attach stale Bearer', () async {
    final out = <RequestOptions>[];
    await interceptor.onRequest(
      RequestOptions(path: ApiPaths.authPhoneOtpVerify, method: 'POST'),
      _CaptureHandler(out),
    );
    expect(out.single.headers['Authorization'], isNull);
  });

  test('email OTP paths remain public', () async {
    final out = <RequestOptions>[];
    await interceptor.onRequest(
      RequestOptions(path: ApiPaths.authOtpRequest, method: 'POST'),
      _CaptureHandler(out),
    );
    expect(out.single.headers['Authorization'], isNull);
  });

  test('protected paths still attach Bearer', () async {
    final out = <RequestOptions>[];
    await interceptor.onRequest(
      RequestOptions(path: ApiPaths.wallet, method: 'GET'),
      _CaptureHandler(out),
    );
    expect(out.single.headers['Authorization'], 'Bearer stale-access');
  });
}
