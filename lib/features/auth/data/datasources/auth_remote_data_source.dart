import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/result.dart';
import '../dto/auth_dto.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final ApiClient _client;

  Future<Result<OtpChallengeDto>> requestPhoneOtp(String phone) {
    return _client.post(
      ApiPaths.authPhoneOtpRequest,
      body: {'phone': phone},
      parser: (data) => OtpChallengeDto.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Result<SessionDto>> verifyPhoneOtp({
    required String phone,
    required String otp,
  }) {
    return _client.post(
      ApiPaths.authPhoneOtpVerify,
      body: {'phone': phone, 'otp': otp},
      parser: (data) => SessionDto.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Result<SessionDto>> verifyFirebasePhoneToken(String idToken) {
    return _client.post(
      ApiPaths.authPhoneFirebaseVerify,
      body: {'idToken': idToken},
      parser: (data) => SessionDto.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Result<OtpChallengeDto>> requestOtp(String email) {
    return _client.post(
      ApiPaths.authOtpRequest,
      body: {'email': email},
      parser: (data) => OtpChallengeDto.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Result<SessionDto>> verifyOtp({
    required String email,
    required String otp,
  }) {
    return _client.post(
      ApiPaths.authOtpVerify,
      body: {'email': email, 'otp': otp},
      parser: (data) => SessionDto.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Result<SessionDto>> login({
    required String email,
    required String password,
  }) {
    return _client.post(
      ApiPaths.authLogin,
      body: {'email': email, 'password': password},
      parser: (data) => SessionDto.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Result<SessionDto>> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _client.post(
      ApiPaths.authRegister,
      body: {'email': email, 'password': password, 'displayName': displayName},
      parser: (data) => SessionDto.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Result<void>> logout(String refreshToken) {
    return _client.post(
      ApiPaths.authLogout,
      body: {'refreshToken': refreshToken},
      parser: (_) {},
    );
  }

  Future<Result<AuthUserDto>> me() {
    return _client.get(
      ApiPaths.usersMe,
      parser: (data) => AuthUserDto.fromJson(data as Map<String, dynamic>),
    );
  }
}
