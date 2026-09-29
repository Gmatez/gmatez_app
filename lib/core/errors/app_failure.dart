import 'package:equatable/equatable.dart';

enum FailureKind {
  offline,
  timeout,
  unauthorized,
  forbidden,
  validation,
  rateLimited,
  notFound,
  conflict,
  server,
  otpInvalid,
  otpExpired,
  otpTooManyAttempts,
  otpRateLimited,
  otpResendCooldown,
  otpDeliveryFailed,
  invalidCredentials,
  refreshInvalid,
  userSuspended,
  insufficientFunds,
  callConflict,
  unknown,
}

class AppFailure extends Equatable {
  const AppFailure({
    required this.kind,
    required this.message,
    this.code,
    this.requestId,
    this.statusCode,
    this.retryAfterSeconds,
  });

  final FailureKind kind;
  final String message;
  final String? code;
  final String? requestId;
  final int? statusCode;
  final int? retryAfterSeconds;

  String get userMessage => message;

  @override
  List<Object?> get props => [
    kind,
    message,
    code,
    requestId,
    statusCode,
    retryAfterSeconds,
  ];
}
