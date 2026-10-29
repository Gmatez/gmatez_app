import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';
import 'auth_state.dart';

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future<void>.microtask(restoreSession);
    return const AuthState.unknown();
  }

  LoadCurrentUserUseCase get _loadCurrentUser =>
      ref.read(loadCurrentUserUseCaseProvider);
  RequestOtpUseCase get _requestOtp => ref.read(requestOtpUseCaseProvider);
  VerifyOtpUseCase get _verifyOtp => ref.read(verifyOtpUseCaseProvider);
  LoginUseCase get _login => ref.read(loginUseCaseProvider);
  RegisterUseCase get _register => ref.read(registerUseCaseProvider);
  LogoutUseCase get _logout => ref.read(logoutUseCaseProvider);
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);
  AppConfig get _config => ref.read(appConfigProvider);

  Future<void> restoreSession() async {
    final hasSession = await _repository.hasStoredSession();
    if (!hasSession) {
      state = const AuthState.unauthenticated();
      return;
    }
    final result = await _loadCurrentUser();
    state = switch (result) {
      Success<AuthUser>(:final value) => AuthState.authenticated(value),
      Failure<AuthUser>(:final failure) => AuthState.unauthenticated(
        failure: failure,
      ),
    };
  }

  /// Kicks off Firebase phone-auth verification. Firebase sends and checks
  /// the SMS code entirely client-side; this only drives its callback-based
  /// API and bridges it into an awaitable result so callers (screens) keep
  /// the same `if (ok && mounted) {...}` shape the old flow had.
  Future<bool> startPhoneVerification(String phone) async {
    state = AuthState.authenticating(pendingPhone: phone);
    final completer = Completer<bool>();

    void complete(bool ok) {
      if (!completer.isCompleted) {
        completer.complete(ok);
      }
    }

    try {
      await ref
          .read(firebasePhoneAuthServiceProvider)
          .startVerification(
            phoneNumber: phone,
            forceResendingToken: state.pendingResendToken,
            onCodeSent: (verificationId, resendToken) {
              state = AuthState(
                status: AuthStatus.unauthenticated,
                pendingPhone: phone,
                pendingVerificationId: verificationId,
                pendingResendToken: resendToken,
              );
              _logger.info('Phone verification code sent', feature: 'auth');
              complete(true);
            },
            onAutoVerified: (credential) async {
              complete(await _completeWithCredential(credential, phone));
            },
            onFailed: (error) {
              state = AuthState.unauthenticated(
                failure: ErrorMapper.fromFirebaseAuth(error),
                pendingPhone: phone,
              );
              complete(false);
            },
          );
    } on FirebaseAuthException catch (error) {
      state = AuthState.unauthenticated(
        failure: ErrorMapper.fromFirebaseAuth(error),
        pendingPhone: phone,
      );
      complete(false);
    }

    return completer.future;
  }

  /// Completes sign-in from a manually entered SMS code.
  Future<bool> verifyManualCode(String smsCode) async {
    final phone = state.pendingPhone;
    final verificationId = state.pendingVerificationId;
    if (phone == null ||
        phone.isEmpty ||
        verificationId == null ||
        verificationId.isEmpty) {
      state = const AuthState.unauthenticated(
        failure: AppFailure(
          kind: FailureKind.validation,
          message: 'Please request a code first.',
        ),
      );
      return false;
    }
    final credential = ref
        .read(firebasePhoneAuthServiceProvider)
        .credentialFor(verificationId: verificationId, smsCode: smsCode.trim());
    return _completeWithCredential(credential, phone);
  }

  /// Shared by manual-code entry and Android auto-verification: exchanges a
  /// Firebase credential for an ID token, hands it to the backend (which
  /// issues this app's own session), then drops the local Firebase client
  /// session — the backend's JWT remains the sole source of truth.
  Future<bool> _completeWithCredential(
    PhoneAuthCredential credential,
    String phone,
  ) async {
    state = AuthState.authenticating(pendingPhone: phone);
    final service = ref.read(firebasePhoneAuthServiceProvider);
    try {
      final idToken = await service.signInAndGetIdToken(credential);
      final result = await _repository.verifyFirebasePhoneToken(idToken);
      await service.signOut();
      return _completeSession(result);
    } on FirebaseAuthException catch (error) {
      state = AuthState.unauthenticated(
        failure: ErrorMapper.fromFirebaseAuth(error),
        pendingPhone: phone,
      );
      return false;
    }
  }

  Future<bool> requestOtp(String email) async {
    state = AuthState.authenticating(pendingEmail: email);
    final result = await _requestOtp(email);
    switch (result) {
      case Success<OtpChallenge>(:final value):
        state = AuthState(
          status: AuthStatus.unauthenticated,
          pendingEmail: email,
          otpExpiresInSeconds: value.expiresInSeconds,
          debugOtp: _config.isProduction ? null : value.debugOtp,
        );
        _logger.info('OTP requested', feature: 'auth');
        return true;
      case Failure<OtpChallenge>(:final failure):
        state = AuthState.unauthenticated(
          failure: failure,
          pendingEmail: email,
        );
        return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    final email = state.pendingEmail;
    if (email == null || email.isEmpty) {
      state = const AuthState.unauthenticated(
        failure: AppFailure(
          kind: FailureKind.validation,
          message: 'Please request a code first.',
        ),
      );
      return false;
    }
    state = AuthState.authenticating(pendingEmail: email);
    final result = await _verifyOtp(email: email, otp: otp);
    return _completeSession(result);
  }

  Future<bool> login({required String email, required String password}) async {
    state = AuthState.authenticating(pendingEmail: email);
    return _completeSession(await _login(email: email, password: password));
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = AuthState.authenticating(pendingEmail: email);
    return _completeSession(
      await _register(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  Future<void> logout() async {
    await _logout();
    state = const AuthState.unauthenticated();
  }

  void markSessionExpired() {
    state = const AuthState.unauthenticated(
      failure: AppFailure(
        kind: FailureKind.unauthorized,
        message: 'Please sign in again.',
        code: 'UNAUTHENTICATED',
      ),
    );
  }

  void markAccountSuspended({AuthUser? user}) {
    state = AuthState.suspended(
      user: user ?? state.user,
      failure: const AppFailure(
        kind: FailureKind.userSuspended,
        message: 'This account has been suspended.',
        code: 'ACCOUNT_SUSPENDED',
      ),
    );
  }

  Future<bool> _completeSession(Result<Session> result) async {
    switch (result) {
      case Failure<Session>(:final failure):
        if (failure.kind == FailureKind.userSuspended ||
            failure.code == 'ACCOUNT_SUSPENDED' ||
            failure.code == 'USER_SUSPENDED') {
          state = AuthState.suspended(failure: failure);
          return false;
        }
        state = AuthState.unauthenticated(
          failure: failure,
          pendingEmail: state.pendingEmail,
          pendingPhone: state.pendingPhone,
        );
        return false;
      case Success<Session>():
        final me = await _loadCurrentUser();
        switch (me) {
          case Success<AuthUser>(:final value):
            if (value.isSuspended) {
              await _repository.clearLocalSession();
              state = AuthState.suspended(user: value);
              return false;
            }
            state = AuthState.authenticated(value);
            return true;
          case Failure<AuthUser>(:final failure):
            if (failure.kind == FailureKind.userSuspended ||
                failure.code == 'ACCOUNT_SUSPENDED' ||
                failure.code == 'USER_SUSPENDED') {
              state = AuthState.suspended(failure: failure);
              return false;
            }
            state = AuthState.unauthenticated(failure: failure);
            return false;
        }
    }
  }

  Future<void> refreshUser() async {
    final result = await _loadCurrentUser();
    if (result case Success<AuthUser>(:final value)) {
      if (value.isSuspended) {
        await _repository.clearLocalSession();
        state = AuthState.suspended(user: value);
        return;
      }
      state = AuthState.authenticated(value);
    } else if (result case Failure<AuthUser>(:final failure)) {
      if (failure.kind == FailureKind.userSuspended ||
          failure.code == 'ACCOUNT_SUSPENDED' ||
          failure.code == 'USER_SUSPENDED') {
        state = AuthState.suspended(failure: failure);
      }
    }
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError('Override authRepositoryProvider in bootstrap');
});

final loadCurrentUserUseCaseProvider = Provider<LoadCurrentUserUseCase>((ref) {
  return LoadCurrentUserUseCase(ref.watch(authRepositoryProvider));
});

final requestOtpUseCaseProvider = Provider<RequestOtpUseCase>((ref) {
  return RequestOtpUseCase(ref.watch(authRepositoryProvider));
});

final verifyOtpUseCaseProvider = Provider<VerifyOtpUseCase>((ref) {
  return VerifyOtpUseCase(ref.watch(authRepositoryProvider));
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  return RegisterUseCase(ref.watch(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});
