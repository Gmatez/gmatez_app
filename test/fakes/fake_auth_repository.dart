import 'package:gmatez_app/core/utils/result.dart';
import 'package:gmatez_app/features/auth/domain/entities/session.dart';
import 'package:gmatez_app/features/auth/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.requestOtpResult,
    this.verifyOtpResult,
    this.loginResult,
    this.registerResult,
    this.currentUserResult,
    this.stored = false,
  });

  Result<OtpChallenge>? requestOtpResult;
  Result<Session>? verifyOtpResult;
  Result<Session>? loginResult;
  Result<Session>? registerResult;
  Result<AuthUser>? currentUserResult;
  bool stored;
  int requestOtpCalls = 0;

  static const sampleSession = Session(
    accessToken: 'access',
    refreshToken: 'refresh',
    tokenType: 'Bearer',
    expiresIn: '15m',
  );

  static const sampleUser = AuthUser(
    id: 'user-1',
    email: 'alice@example.com',
    role: 'USER',
    status: 'ACTIVE',
    displayName: 'Alice',
  );

  @override
  Future<Result<OtpChallenge>> requestPhoneOtp(String phone) async {
    requestOtpCalls += 1;
    return requestOtpResult ??
        const Success(OtpChallenge(expiresInSeconds: 300, debugOtp: '123456'));
  }

  @override
  Future<Result<Session>> verifyPhoneOtp({
    required String phone,
    required String otp,
  }) async {
    return verifyOtpResult ?? const Success(sampleSession);
  }

  @override
  Future<Result<OtpChallenge>> requestOtp(String email) async {
    requestOtpCalls += 1;
    return requestOtpResult ??
        const Success(OtpChallenge(expiresInSeconds: 300, debugOtp: '123456'));
  }

  @override
  Future<Result<Session>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    return verifyOtpResult ?? const Success(sampleSession);
  }

  @override
  Future<Result<Session>> login({
    required String email,
    required String password,
  }) async {
    return loginResult ?? const Success(sampleSession);
  }

  @override
  Future<Result<Session>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return registerResult ?? const Success(sampleSession);
  }

  @override
  Future<Result<void>> logout() async {
    stored = false;
    return const Success(null);
  }

  @override
  Future<Result<AuthUser>> currentUser() async {
    return currentUserResult ?? const Success(sampleUser);
  }

  @override
  Future<bool> hasStoredSession() async => stored;

  @override
  Future<void> clearLocalSession() async {
    stored = false;
  }
}
