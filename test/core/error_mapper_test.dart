import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/core/errors/app_failure.dart';
import 'package:gmatez_app/core/errors/error_mapper.dart';

void main() {
  test('maps backend OTP error to a user-safe message', () {
    final failure = ErrorMapper.fromCode(code: 'OTP_INVALID', statusCode: 401);
    expect(failure.kind, FailureKind.otpInvalid);
    expect(failure.userMessage, 'That code is incorrect. Please try again.');
  });

  test('maps OTP rate limit with retryAfterSeconds', () {
    final failure = ErrorMapper.fromCode(
      code: 'OTP_RESEND_COOLDOWN',
      statusCode: 429,
      details: {'retryAfterSeconds': 45},
    );
    expect(failure.kind, FailureKind.otpResendCooldown);
    expect(failure.retryAfterSeconds, 45);
  });

  test('maps account suspended', () {
    final failure = ErrorMapper.fromCode(
      code: 'ACCOUNT_SUSPENDED',
      statusCode: 403,
    );
    expect(failure.kind, FailureKind.userSuspended);
  });

  test('maps 500 to a generic retry message', () {
    final failure = ErrorMapper.fromDio(
      DioException(
        requestOptions: RequestOptions(path: '/wallet'),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/wallet'),
          statusCode: 500,
          data: {
            'error': {
              'code': 'INTERNAL',
              'message': 'Internal server error',
              'requestId': 'abc',
            },
          },
        ),
        type: DioExceptionType.badResponse,
      ),
    );
    expect(failure.kind, FailureKind.server);
    expect(failure.userMessage, 'Something went wrong. Please try again.');
    expect(failure.requestId, 'abc');
  });

  test('maps connection errors to offline', () {
    final failure = ErrorMapper.fromDio(
      DioException(
        requestOptions: RequestOptions(path: '/users/me'),
        type: DioExceptionType.connectionError,
      ),
    );
    expect(failure.kind, FailureKind.offline);
  });

  test('maps UNAUTHORIZED and insufficient balance aliases', () {
    expect(
      ErrorMapper.fromCode(code: 'UNAUTHORIZED').userMessage,
      'Your session has expired. Please log in again.',
    );
    expect(
      ErrorMapper.fromCode(code: 'INSUFFICIENT_BALANCE').userMessage,
      'Your balance is too low for this call.',
    );
    expect(
      ErrorMapper.fromCode(code: 'HOST_OFFLINE').userMessage,
      'This host is currently unavailable.',
    );
    expect(
      ErrorMapper.fromCode(code: 'HOST_BUSY').userMessage,
      'This host is currently on another call.',
    );
  });
}
