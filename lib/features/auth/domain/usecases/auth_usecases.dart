import '../../../../core/utils/result.dart';
import '../entities/session.dart';
import '../repositories/auth_repository.dart';

class RequestOtpUseCase {
  const RequestOtpUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<OtpChallenge>> call(String email) {
    return _repository.requestOtp(email.trim().toLowerCase());
  }
}

class VerifyOtpUseCase {
  const VerifyOtpUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<Session>> call({required String email, required String otp}) {
    return _repository.verifyOtp(
      email: email.trim().toLowerCase(),
      otp: otp.trim(),
    );
  }
}

class LoginUseCase {
  const LoginUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<Session>> call({
    required String email,
    required String password,
  }) {
    return _repository.login(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }
}

class RegisterUseCase {
  const RegisterUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<Session>> call({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _repository.register(
      email: email.trim().toLowerCase(),
      password: password,
      displayName: displayName.trim(),
    );
  }
}

class LogoutUseCase {
  const LogoutUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.logout();
}

class LoadCurrentUserUseCase {
  const LoadCurrentUserUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<AuthUser>> call() => _repository.currentUser();
}
