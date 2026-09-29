import 'package:equatable/equatable.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/session.dart';

enum AuthStatus {
  unknown,
  unauthenticated,
  authenticating,
  authenticated,
  suspended,
}

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.user,
    this.failure,
    this.pendingEmail,
    this.pendingPhone,
    this.debugOtp,
    this.otpExpiresInSeconds,
    this.otpResendAvailableInSeconds,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.unauthenticated({
    AppFailure? failure,
    String? pendingEmail,
    String? pendingPhone,
  }) : this(
         status: AuthStatus.unauthenticated,
         failure: failure,
         pendingEmail: pendingEmail,
         pendingPhone: pendingPhone,
       );

  const AuthState.authenticating({String? pendingEmail, String? pendingPhone})
    : this(
        status: AuthStatus.authenticating,
        pendingEmail: pendingEmail,
        pendingPhone: pendingPhone,
      );

  const AuthState.authenticated(AuthUser user)
    : this(status: AuthStatus.authenticated, user: user);

  const AuthState.suspended({AuthUser? user, AppFailure? failure})
    : this(status: AuthStatus.suspended, user: user, failure: failure);

  final AuthStatus status;
  final AuthUser? user;
  final AppFailure? failure;
  final String? pendingEmail;
  final String? pendingPhone;
  final String? debugOtp;
  final int? otpExpiresInSeconds;
  final int? otpResendAvailableInSeconds;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isSuspended => status == AuthStatus.suspended;
  bool get isUnknown => status == AuthStatus.unknown;
  bool get isBusy =>
      status == AuthStatus.authenticating || status == AuthStatus.unknown;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    AppFailure? failure,
    String? pendingEmail,
    String? pendingPhone,
    String? debugOtp,
    int? otpExpiresInSeconds,
    int? otpResendAvailableInSeconds,
    bool clearFailure = false,
    bool clearDebugOtp = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      failure: clearFailure ? null : failure ?? this.failure,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      pendingPhone: pendingPhone ?? this.pendingPhone,
      debugOtp: clearDebugOtp ? null : debugOtp ?? this.debugOtp,
      otpExpiresInSeconds: otpExpiresInSeconds ?? this.otpExpiresInSeconds,
      otpResendAvailableInSeconds:
          otpResendAvailableInSeconds ?? this.otpResendAvailableInSeconds,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    failure,
    pendingEmail,
    pendingPhone,
    otpExpiresInSeconds,
    otpResendAvailableInSeconds,
  ];
}
