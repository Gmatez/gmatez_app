import 'package:dio/dio.dart';

import '../errors/app_failure.dart';
import '../network/api_error_dto.dart';

abstract final class ErrorMapper {
  static const _userMessages = <String, String>{
    'VALIDATION_FAILED': 'Please check the information you entered.',
    'UNAUTHENTICATED': 'Your session has expired. Please log in again.',
    'UNAUTHORIZED': 'Your session has expired. Please log in again.',
    'FORBIDDEN': 'You do not have permission to do that.',
    'NOT_FOUND': 'We could not find what you were looking for.',
    'CONFLICT': 'That action conflicts with the current state.',
    'RATE_LIMITED': 'Too many attempts. Please wait and try again.',
    'USER_SUSPENDED': 'This account has been suspended.',
    'ACCOUNT_SUSPENDED': 'This account has been suspended.',
    'ACCOUNT_DELETED': 'This account is no longer available.',
    'INVALID_CREDENTIALS': 'Those credentials are incorrect.',
    'REFRESH_TOKEN_INVALID': 'Your session expired. Please sign in again.',
    'AUTH_INVALID_SESSION': 'Your session expired. Please sign in again.',
    'AUTH_REFRESH_REUSED': 'Your session was revoked. Please sign in again.',
    'AUTH_SESSION_REVOKED': 'Your session was revoked. Please sign in again.',
    'OTP_INVALID': 'That code is incorrect. Please try again.',
    'OTP_EXPIRED': 'That code expired. Request a new one.',
    'OTP_TOO_MANY_ATTEMPTS': 'Too many incorrect codes. Request a new one.',
    'OTP_RATE_LIMITED': 'Too many attempts. Please wait and try again.',
    'OTP_RESEND_COOLDOWN': 'Please wait before requesting another code.',
    'OTP_DELIVERY_FAILED':
        'We could not send the verification code. Please try again.',
    'WALLET_INSUFFICIENT_FUNDS': 'Your balance is too low for this call.',
    'INSUFFICIENT_BALANCE': 'Your balance is too low for this call.',
    'CALL_FAILED': 'Unable to connect the call. Please try again.',
    'CALL_INVALID_TRANSITION': 'This call cannot be updated right now.',
    'CALL_NOT_PARTICIPANT': 'You are not part of this call.',
    'CALL_ALREADY_ACTIVE': 'You already have an active call.',
    'USER_BLOCKED': 'This user is unavailable.',
    'USER_BUSY': 'This user is currently unavailable.',
    'HOST_OFFLINE': 'This host is currently unavailable.',
    'HOST_BUSY': 'This host is currently on another call.',
    'HOST_NOT_APPROVED': 'This host is currently unavailable.',
    'HOST_NOT_ACTIVE': 'This host is not available yet.',
    'HOST_NOT_DISCOVERABLE': 'This host is currently unavailable.',
    'HOST_UNAVAILABLE': 'This host is currently unavailable.',
    'HOST_CALL_TYPE_DISABLED': 'This call type is not available for this host.',
    'HOST_APPLICATION_EXISTS': 'A host application is already in progress.',
    'HOST_APPLICATION_INVALID': 'Please complete the host application details.',
    'HOST_INCOMPLETE': 'Complete your host profile before going online.',
    'HOST_VERIFICATION_REQUIRED': 'Host verification is still required.',
    'HOST_AGREEMENT_REQUIRED': 'Please accept the required host agreements.',
    'HOST_SUSPENDED': 'This host account is suspended.',
    'CONVERSATION_NOT_FOUND': 'Conversation not found.',
    'CONVERSATION_FORBIDDEN': 'You cannot access this conversation.',
    'MESSAGE_INVALID': 'That message could not be sent.',
    'MESSAGE_TOO_LONG': 'That message is too long.',
    'MESSAGE_RATE_LIMITED': 'You are sending messages too quickly.',
    'MESSAGE_BLOCKED': 'Messaging is unavailable with this user.',
    'MESSAGE_NOT_FOUND': 'Message not found.',
    'SOCKET_UNAUTHORIZED': 'Realtime connection is not authorized.',
    'SOCKET_ROOM_FORBIDDEN': 'You cannot join that chat room.',
    'PAYOUT_FAILED': "We couldn't process the payout. Please try again.",
    'PAYOUT_NOT_ELIGIBLE': 'This payout cannot be requested right now.',
    'INTERNAL': 'Something went wrong. Please try again.',
  };

  static AppFailure fromDio(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        (error.type == DioExceptionType.unknown && error.response == null)) {
      return const AppFailure(
        kind: FailureKind.offline,
        message:
            'Cannot reach the Gmatez server. If it has been idle, wait about a minute and try again.',
        code: 'OFFLINE',
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const AppFailure(
        kind: FailureKind.timeout,
        message: 'The request took too long. Please try again.',
        code: 'TIMEOUT',
      );
    }

    final status = error.response?.statusCode;
    final data = error.response?.data;
    ApiErrorDto? dto;
    if (data is Map<String, dynamic>) {
      dto = ApiErrorDto.fromJson(data);
    }

    return fromCode(
      code: dto?.code,
      requestId: dto?.requestId,
      statusCode: status,
      details: dto?.details,
    );
  }

  static AppFailure fromCode({
    required String? code,
    String? requestId,
    int? statusCode,
    Map<String, dynamic>? details,
  }) {
    final resolvedCode = code ?? _codeFromStatus(statusCode);
    final retryAfter = _retryAfter(details);
    return AppFailure(
      kind: _kindFor(resolvedCode, statusCode),
      message:
          _userMessages[resolvedCode] ??
          'Something went wrong. Please try again.',
      code: resolvedCode,
      requestId: requestId,
      statusCode: statusCode,
      retryAfterSeconds: retryAfter,
    );
  }

  static int? _retryAfter(Map<String, dynamic>? details) {
    final value = details?['retryAfterSeconds'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static FailureKind _kindFor(String code, int? status) {
    return switch (code) {
      'UNAUTHENTICATED' => FailureKind.unauthorized,
      'UNAUTHORIZED' => FailureKind.unauthorized,
      'AUTH_INVALID_SESSION' => FailureKind.refreshInvalid,
      'AUTH_REFRESH_REUSED' => FailureKind.refreshInvalid,
      'AUTH_SESSION_REVOKED' => FailureKind.refreshInvalid,
      'FORBIDDEN' => FailureKind.forbidden,
      'VALIDATION_FAILED' => FailureKind.validation,
      'RATE_LIMITED' => FailureKind.rateLimited,
      'OTP_RATE_LIMITED' => FailureKind.otpRateLimited,
      'OTP_RESEND_COOLDOWN' => FailureKind.otpResendCooldown,
      'OTP_TOO_MANY_ATTEMPTS' => FailureKind.otpTooManyAttempts,
      'OTP_DELIVERY_FAILED' => FailureKind.otpDeliveryFailed,
      'OTP_EXPIRED' => FailureKind.otpExpired,
      'NOT_FOUND' => FailureKind.notFound,
      'CONFLICT' => FailureKind.conflict,
      'OTP_INVALID' => FailureKind.otpInvalid,
      'INVALID_CREDENTIALS' => FailureKind.invalidCredentials,
      'REFRESH_TOKEN_INVALID' => FailureKind.refreshInvalid,
      'USER_SUSPENDED' => FailureKind.userSuspended,
      'ACCOUNT_SUSPENDED' => FailureKind.userSuspended,
      'ACCOUNT_DELETED' => FailureKind.unauthorized,
      'WALLET_INSUFFICIENT_FUNDS' => FailureKind.insufficientFunds,
      'INSUFFICIENT_BALANCE' => FailureKind.insufficientFunds,
      'CALL_ALREADY_ACTIVE' => FailureKind.callConflict,
      'INTERNAL' => FailureKind.server,
      _ => switch (status) {
        401 => FailureKind.unauthorized,
        403 => FailureKind.forbidden,
        404 => FailureKind.notFound,
        409 => FailureKind.conflict,
        422 => FailureKind.validation,
        429 => FailureKind.rateLimited,
        int s when s >= 500 => FailureKind.server,
        _ => FailureKind.unknown,
      },
    };
  }

  static String _codeFromStatus(int? status) {
    return switch (status) {
      401 => 'UNAUTHENTICATED',
      403 => 'FORBIDDEN',
      404 => 'NOT_FOUND',
      409 => 'CONFLICT',
      422 => 'VALIDATION_FAILED',
      429 => 'RATE_LIMITED',
      int s when s >= 500 => 'INTERNAL',
      _ => 'INTERNAL',
    };
  }
}
