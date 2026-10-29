import '../../../../core/utils/result.dart';
import '../entities/session.dart';

abstract class AuthRepository {
  Future<Result<OtpChallenge>> requestOtp(String email);
  Future<Result<OtpChallenge>> requestPhoneOtp(String phone);
  Future<Result<Session>> verifyPhoneOtp({
    required String phone,
    required String otp,
  });
  Future<Result<Session>> verifyFirebasePhoneToken(String idToken);
  Future<Result<Session>> verifyOtp({
    required String email,
    required String otp,
  });
  Future<Result<Session>> login({
    required String email,
    required String password,
  });
  Future<Result<Session>> register({
    required String email,
    required String password,
    required String displayName,
  });
  Future<Result<void>> logout();
  Future<Result<AuthUser>> currentUser();
  Future<bool> hasStoredSession();
  Future<void> clearLocalSession();
}
