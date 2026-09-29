import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HostOnboardingState extends Equatable {
  const HostOnboardingState({
    this.displayName = '',
    this.gender = 'UNSPECIFIED',
    this.language = 'en',
    this.bio = '',
    this.languages = const ['English'],
    this.interests = const [],
    this.voiceEnabled = true,
    this.videoEnabled = true,
    this.voiceRatePerMinuteCents = 100,
    this.videoRatePerMinuteCents = 150,
    this.agreementAccepted = false,
    this.guidelinesAccepted = false,
    this.termsAccepted = false,
    this.privacyAccepted = false,
    this.verificationAcknowledged = false,
    this.step = 0,
  });

  final String displayName;
  final String gender;
  final String language;
  final String bio;
  final List<String> languages;
  final List<String> interests;
  final bool voiceEnabled;
  final bool videoEnabled;
  final int voiceRatePerMinuteCents;
  final int videoRatePerMinuteCents;
  final bool agreementAccepted;
  final bool guidelinesAccepted;
  final bool termsAccepted;
  final bool privacyAccepted;
  final bool verificationAcknowledged;
  final int step;

  bool get canSubmit =>
      agreementAccepted &&
      guidelinesAccepted &&
      termsAccepted &&
      privacyAccepted &&
      languages.isNotEmpty &&
      interests.isNotEmpty &&
      bio.trim().length >= 8 &&
      displayName.trim().length >= 2;

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'gender': gender,
    'language': language,
    'bio': bio,
    'languages': languages,
    'interests': interests,
    'voiceEnabled': voiceEnabled,
    'videoEnabled': videoEnabled,
    'voiceRatePerMinuteCents': voiceRatePerMinuteCents,
    'videoRatePerMinuteCents': videoRatePerMinuteCents,
    'agreementAccepted': agreementAccepted,
    'guidelinesAccepted': guidelinesAccepted,
    'termsAccepted': termsAccepted,
    'privacyAccepted': privacyAccepted,
    'verificationAcknowledged': verificationAcknowledged,
    'step': step,
  };

  factory HostOnboardingState.fromJson(Map<String, dynamic> json) {
    return HostOnboardingState(
      displayName: json['displayName'] as String? ?? '',
      gender: json['gender'] as String? ?? 'UNSPECIFIED',
      language: json['language'] as String? ?? 'en',
      bio: json['bio'] as String? ?? '',
      languages:
          (json['languages'] as List?)?.whereType<String>().toList() ??
          const ['English'],
      interests:
          (json['interests'] as List?)?.whereType<String>().toList() ??
          const [],
      voiceEnabled: json['voiceEnabled'] as bool? ?? true,
      videoEnabled: json['videoEnabled'] as bool? ?? true,
      voiceRatePerMinuteCents:
          (json['voiceRatePerMinuteCents'] as num?)?.toInt() ?? 100,
      videoRatePerMinuteCents:
          (json['videoRatePerMinuteCents'] as num?)?.toInt() ?? 150,
      agreementAccepted: json['agreementAccepted'] as bool? ?? false,
      guidelinesAccepted: json['guidelinesAccepted'] as bool? ?? false,
      termsAccepted: json['termsAccepted'] as bool? ?? false,
      privacyAccepted: json['privacyAccepted'] as bool? ?? false,
      verificationAcknowledged:
          json['verificationAcknowledged'] as bool? ?? false,
      step: (json['step'] as num?)?.toInt() ?? 0,
    );
  }

  HostOnboardingState copyWith({
    String? displayName,
    String? gender,
    String? language,
    String? bio,
    List<String>? languages,
    List<String>? interests,
    bool? voiceEnabled,
    bool? videoEnabled,
    int? voiceRatePerMinuteCents,
    int? videoRatePerMinuteCents,
    bool? agreementAccepted,
    bool? guidelinesAccepted,
    bool? termsAccepted,
    bool? privacyAccepted,
    bool? verificationAcknowledged,
    int? step,
  }) {
    return HostOnboardingState(
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      language: language ?? this.language,
      bio: bio ?? this.bio,
      languages: languages ?? this.languages,
      interests: interests ?? this.interests,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      videoEnabled: videoEnabled ?? this.videoEnabled,
      voiceRatePerMinuteCents:
          voiceRatePerMinuteCents ?? this.voiceRatePerMinuteCents,
      videoRatePerMinuteCents:
          videoRatePerMinuteCents ?? this.videoRatePerMinuteCents,
      agreementAccepted: agreementAccepted ?? this.agreementAccepted,
      guidelinesAccepted: guidelinesAccepted ?? this.guidelinesAccepted,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      verificationAcknowledged:
          verificationAcknowledged ?? this.verificationAcknowledged,
      step: step ?? this.step,
    );
  }

  @override
  List<Object?> get props => [
    displayName,
    gender,
    language,
    bio,
    languages,
    interests,
    voiceEnabled,
    videoEnabled,
    voiceRatePerMinuteCents,
    videoRatePerMinuteCents,
    agreementAccepted,
    guidelinesAccepted,
    termsAccepted,
    privacyAccepted,
    verificationAcknowledged,
    step,
  ];
}

class HostOnboardingNotifier extends Notifier<HostOnboardingState> {
  static const _draftKey = 'host.onboarding.draft.v1';

  @override
  HostOnboardingState build() => const HostOnboardingState();

  Future<void> restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        state = HostOnboardingState.fromJson(decoded);
      } else if (decoded is Map) {
        state = HostOnboardingState.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      await prefs.remove(_draftKey);
    }
  }

  Future<void> persistDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(state.toJson()));
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  void hydrate({String? displayName, String? gender, String? language}) {
    state = state.copyWith(
      displayName: displayName ?? state.displayName,
      gender: gender ?? state.gender,
      language: language ?? state.language,
    );
  }

  void setStep(int step) {
    state = state.copyWith(step: step);
    unawaitedPersist();
  }

  void patch(HostOnboardingState next) {
    state = next;
    unawaitedPersist();
  }

  void toggleLanguage(String value) {
    final next = [...state.languages];
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    state = state.copyWith(languages: next);
    unawaitedPersist();
  }

  void toggleInterest(String value) {
    final next = [...state.interests];
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    state = state.copyWith(interests: next);
    unawaitedPersist();
  }

  void unawaitedPersist() {
    // Fire-and-forget local draft save for process death / navigation resume.
    persistDraft();
  }
}

final hostOnboardingProvider =
    NotifierProvider<HostOnboardingNotifier, HostOnboardingState>(
      HostOnboardingNotifier.new,
    );

const kHostLanguages = [
  'English',
  'Hindi',
  'Malayalam',
  'Tamil',
  'Kannada',
  'Telugu',
  'Bengali',
  'Marathi',
];

/// Backend expects language tags matching /^[a-z-]{2,16}$/.
const kHostLanguageCodes = <String, String>{
  'English': 'en',
  'Hindi': 'hi',
  'Malayalam': 'ml',
  'Tamil': 'ta',
  'Kannada': 'kn',
  'Telugu': 'te',
  'Bengali': 'bn',
  'Marathi': 'mr',
};

String hostLanguageCode(String labelOrCode) {
  final trimmed = labelOrCode.trim();
  if (kHostLanguageCodes.containsKey(trimmed)) {
    return kHostLanguageCodes[trimmed]!;
  }
  final lower = trimmed.toLowerCase();
  if (RegExp(r'^[a-z-]{2,16}$').hasMatch(lower)) {
    return lower;
  }
  if (trimmed.length >= 2) {
    return trimmed.toLowerCase().substring(0, 2);
  }
  return 'en';
}

String hostInterestSlug(String label) {
  return label
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '')
      .clampLength(24);
}

extension HostStringX on String {
  String clampLength(int max) => length <= max ? this : substring(0, max);
}

const kHostInterests = [
  'Music',
  'Movies',
  'Travel',
  'Gaming',
  'Fitness',
  'Study',
  'Food',
  'Lifestyle',
  'Sports',
];
