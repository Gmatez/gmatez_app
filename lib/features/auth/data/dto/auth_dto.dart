import '../../domain/entities/session.dart';

class SessionDto {
  const SessionDto({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final String expiresIn;

  factory SessionDto.fromJson(Map<String, dynamic> json) {
    return SessionDto(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: json['expiresIn'] as String? ?? '',
    );
  }

  Session toDomain() {
    return Session(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      expiresIn: expiresIn,
    );
  }
}

class OtpChallengeDto {
  const OtpChallengeDto({
    required this.expiresInSeconds,
    this.resendAvailableInSeconds,
    this.debugOtp,
  });

  final int expiresInSeconds;
  final int? resendAvailableInSeconds;
  final String? debugOtp;

  factory OtpChallengeDto.fromJson(Map<String, dynamic> json) {
    return OtpChallengeDto(
      expiresInSeconds: json['expiresInSeconds'] as int? ?? 300,
      resendAvailableInSeconds: json['resendAvailableInSeconds'] as int?,
      debugOtp: json['otp'] as String?,
    );
  }

  OtpChallenge toDomain() {
    return OtpChallenge(
      expiresInSeconds: expiresInSeconds,
      resendAvailableInSeconds: resendAvailableInSeconds,
      debugOtp: debugOtp,
    );
  }
}

class AuthUserDto {
  const AuthUserDto({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    this.displayName,
    this.phone,
    this.host,
  });

  final String id;
  final String email;
  final String role;
  final String status;
  final String? displayName;
  final String? phone;
  final HostSnapshot? host;

  factory AuthUserDto.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'];
    final hostJson = json['host'];
    return AuthUserDto(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String? ?? 'USER',
      status: json['status'] as String? ?? 'ACTIVE',
      displayName: profile is Map<String, dynamic>
          ? profile['displayName'] as String?
          : null,
      phone: json['phone'] as String?,
      host: hostJson is Map<String, dynamic>
          ? HostSnapshot.fromJson(hostJson)
          : null,
    );
  }

  AuthUser toDomain() {
    return AuthUser(
      id: id,
      email: email,
      role: role,
      status: status,
      displayName: displayName,
      phone: phone,
      host: host,
    );
  }
}
