import 'package:equatable/equatable.dart';

class Session extends Equatable {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final String expiresIn;

  @override
  List<Object?> get props => [tokenType, expiresIn];
}

class OtpChallenge extends Equatable {
  const OtpChallenge({
    required this.expiresInSeconds,
    this.resendAvailableInSeconds,
    this.debugOtp,
  });

  final int expiresInSeconds;
  final int? resendAvailableInSeconds;
  final String? debugOtp;

  @override
  List<Object?> get props => [expiresInSeconds, resendAvailableInSeconds];
}

class AuthUser extends Equatable {
  const AuthUser({
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

  bool get isAdmin => role == 'ADMIN';
  bool get isActiveHost => host?.status == 'ACTIVE';
  bool get isPendingHost => host?.status == 'PENDING_REVIEW';
  bool get isRejectedHost => host?.status == 'REJECTED';
  bool get isSuspendedHost => host?.status == 'SUSPENDED';
  bool get isSuspended => status == 'SUSPENDED';
  bool get isDeleted => status == 'DELETED';
  bool get isActiveAccount => status == 'ACTIVE';

  @override
  List<Object?> get props => [id, email, role, status, displayName, phone, host];
}

class HostSnapshot extends Equatable {
  const HostSnapshot({
    required this.status,
    required this.availability,
    this.verificationStatus = 'NOT_REQUIRED',
    this.voiceEnabled = true,
    this.videoEnabled = true,
    this.voiceRatePerMinuteCents = 100,
    this.videoRatePerMinuteCents = 150,
    this.languages = const [],
    this.interests = const [],
    this.applicationBio = '',
    this.reviewNote,
  });

  final String status;
  final String availability;
  final String verificationStatus;
  final bool voiceEnabled;
  final bool videoEnabled;
  final int voiceRatePerMinuteCents;
  final int videoRatePerMinuteCents;
  final List<String> languages;
  final List<String> interests;
  final String applicationBio;
  final String? reviewNote;

  factory HostSnapshot.fromJson(Map<String, dynamic> json) {
    return HostSnapshot(
      status: json['status'] as String? ?? 'PENDING_REVIEW',
      availability: json['availability'] as String? ?? 'OFFLINE',
      verificationStatus:
          json['verificationStatus'] as String? ?? 'NOT_REQUIRED',
      voiceEnabled: json['voiceEnabled'] as bool? ?? true,
      videoEnabled: json['videoEnabled'] as bool? ?? true,
      voiceRatePerMinuteCents:
          (json['voiceRatePerMinuteCents'] as num?)?.toInt() ?? 100,
      videoRatePerMinuteCents:
          (json['videoRatePerMinuteCents'] as num?)?.toInt() ?? 150,
      languages:
          (json['languages'] as List?)?.whereType<String>().toList() ??
          const [],
      interests:
          (json['interests'] as List?)?.whereType<String>().toList() ??
          const [],
      applicationBio: json['applicationBio'] as String? ?? '',
      reviewNote: json['reviewNote'] as String?,
    );
  }

  @override
  List<Object?> get props => [status, availability, verificationStatus];
}
