import '../../../../core/network/token_store.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../dto/auth_dto.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required TokenStore tokenStore,
  }) : _remote = remote,
       _tokenStore = tokenStore;

  final AuthRemoteDataSource _remote;
  final TokenStore _tokenStore;

  @override
  Future<Result<OtpChallenge>> requestPhoneOtp(String phone) async {
    final result = await _remote.requestPhoneOtp(phone);
    return result.fold(
      onSuccess: (dto) => Success(dto.toDomain()),
      onFailure: Failure.new,
    );
  }

  @override
  Future<Result<Session>> verifyPhoneOtp({
    required String phone,
    required String otp,
  }) {
    return _persistSession(_remote.verifyPhoneOtp(phone: phone, otp: otp));
  }

  @override
  Future<Result<Session>> verifyFirebasePhoneToken(String idToken) {
    return _persistSession(_remote.verifyFirebasePhoneToken(idToken));
  }

  @override
  Future<Result<OtpChallenge>> requestOtp(String email) async {
    final result = await _remote.requestOtp(email);
    return result.fold(
      onSuccess: (dto) => Success(dto.toDomain()),
      onFailure: Failure.new,
    );
  }

  @override
  Future<Result<Session>> verifyOtp({
    required String email,
    required String otp,
  }) {
    return _persistSession(_remote.verifyOtp(email: email, otp: otp));
  }

  @override
  Future<Result<Session>> login({
    required String email,
    required String password,
  }) {
    return _persistSession(_remote.login(email: email, password: password));
  }

  @override
  Future<Result<Session>> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _persistSession(
      _remote.register(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  @override
  Future<Result<void>> logout() async {
    final refresh = await _tokenStore.readRefreshToken();
    if (refresh != null) {
      await _remote.logout(refresh);
    }
    await _tokenStore.clear();
    return const Success(null);
  }

  @override
  Future<Result<AuthUser>> currentUser() async {
    final result = await _remote.me();
    return result.fold(
      onSuccess: (dto) => Success(dto.toDomain()),
      onFailure: Failure.new,
    );
  }

  @override
  Future<bool> hasStoredSession() async {
    final token = await _tokenStore.readAccessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> clearLocalSession() => _tokenStore.clear();

  Future<Result<Session>> _persistSession(
    Future<Result<SessionDto>> request,
  ) async {
    final result = await request;
    switch (result) {
      case Success<SessionDto>(:final value):
        final session = value.toDomain();
        await _tokenStore.writeTokens(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        );
        return Success(session);
      case Failure<SessionDto>(:final failure):
        return Failure(failure);
    }
  }
}
