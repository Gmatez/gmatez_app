import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.bio,
    required this.gender,
    required this.ratePerMinuteCents,
    required this.online,
    required this.availableForCall,
    this.country,
    this.language,
    this.avatarUrl,
    this.isDiscoverable = true,
    this.lastActiveAt,
    this.hostStatus,
    this.hostAvailability,
    this.voiceEnabled = true,
    this.videoEnabled = true,
    this.voiceRatePerMinuteCents,
    this.videoRatePerMinuteCents,
    this.languages = const [],
    this.interests = const [],
  });

  final String userId;
  final String displayName;
  final String bio;
  final String gender;
  final String? country;
  final String? language;
  final String? avatarUrl;
  final bool isDiscoverable;
  final int ratePerMinuteCents;
  final bool online;
  final bool availableForCall;
  final DateTime? lastActiveAt;
  final String? hostStatus;
  final String? hostAvailability;
  final bool voiceEnabled;
  final bool videoEnabled;
  final int? voiceRatePerMinuteCents;
  final int? videoRatePerMinuteCents;
  final List<String> languages;
  final List<String> interests;

  String get rateLabel {
    final dollars = ratePerMinuteCents / 100;
    return '\$${dollars.toStringAsFixed(dollars.truncateToDouble() == dollars ? 0 : 2)}/min voice';
  }

  String get videoRateLabel {
    final cents = videoRatePerMinuteCents ?? ratePerMinuteCents;
    final dollars = cents / 100;
    return '\$${dollars.toStringAsFixed(dollars.truncateToDouble() == dollars ? 0 : 2)}/min video';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final nested = json['profile'];
    final source = nested is Map<String, dynamic> ? nested : json;
    final host = json['host'];
    final hostMap = host is Map<String, dynamic> ? host : null;
    return UserProfile(
      userId:
          json['userId'] as String? ??
          json['id'] as String? ??
          source['userId'] as String? ??
          '',
      displayName: source['displayName'] as String? ?? '',
      bio: source['bio'] as String? ?? '',
      gender: source['gender'] as String? ?? 'UNSPECIFIED',
      country: source['country'] as String?,
      language: source['language'] as String?,
      avatarUrl: source['avatarUrl'] as String?,
      isDiscoverable: source['isDiscoverable'] as bool? ?? true,
      ratePerMinuteCents:
          (hostMap?['voiceRatePerMinuteCents'] as num?)?.toInt() ??
          (source['ratePerMinuteCents'] as num?)?.toInt() ??
          0,
      online: json['online'] as bool? ?? source['online'] as bool? ?? false,
      availableForCall:
          json['availableForCall'] as bool? ??
          source['availableForCall'] as bool? ??
          hostMap?['availableForCall'] as bool? ??
          false,
      lastActiveAt: DateTime.tryParse(source['lastActiveAt']?.toString() ?? ''),
      hostStatus: hostMap?['status'] as String?,
      hostAvailability: hostMap?['availability'] as String?,
      voiceEnabled: hostMap?['voiceEnabled'] as bool? ?? true,
      videoEnabled: hostMap?['videoEnabled'] as bool? ?? true,
      voiceRatePerMinuteCents: (hostMap?['voiceRatePerMinuteCents'] as num?)
          ?.toInt(),
      videoRatePerMinuteCents: (hostMap?['videoRatePerMinuteCents'] as num?)
          ?.toInt(),
      languages:
          (hostMap?['languages'] as List?)?.whereType<String>().toList() ??
          const [],
      interests:
          (hostMap?['interests'] as List?)?.whereType<String>().toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [
    userId,
    displayName,
    bio,
    gender,
    country,
    language,
    avatarUrl,
    isDiscoverable,
    ratePerMinuteCents,
    online,
    availableForCall,
  ];
}

class ProfileUpdate {
  const ProfileUpdate({
    this.displayName,
    this.bio,
    this.gender,
    this.country,
    this.language,
    this.avatarUrl,
    this.isDiscoverable,
    this.ratePerMinuteCents,
  });

  final String? displayName;
  final String? bio;
  final String? gender;
  final String? country;
  final String? language;
  final String? avatarUrl;
  final bool? isDiscoverable;
  final int? ratePerMinuteCents;

  Map<String, dynamic> toJson() {
    return {
      if (displayName != null) 'displayName': displayName,
      if (bio != null) 'bio': bio,
      if (gender != null) 'gender': gender,
      if (country != null) 'country': country,
      if (language != null) 'language': language,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (isDiscoverable != null) 'isDiscoverable': isDiscoverable,
      if (ratePerMinuteCents != null) 'ratePerMinuteCents': ratePerMinuteCents,
    };
  }
}
