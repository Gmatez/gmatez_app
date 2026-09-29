import 'package:equatable/equatable.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/user_profile.dart';

enum ProfileViewStatus { loading, saving, success, empty, error }

class ProfileViewState extends Equatable {
  const ProfileViewState({
    required this.status,
    this.profile,
    this.failure,
    this.saving = false,
  });

  const ProfileViewState.loading() : this(status: ProfileViewStatus.loading);

  final ProfileViewStatus status;
  final UserProfile? profile;
  final AppFailure? failure;
  final bool saving;

  ProfileViewState copyWith({
    ProfileViewStatus? status,
    UserProfile? profile,
    AppFailure? failure,
    bool? saving,
    bool clearFailure = false,
  }) {
    return ProfileViewState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      failure: clearFailure ? null : failure ?? this.failure,
      saving: saving ?? this.saving,
    );
  }

  @override
  List<Object?> get props => [status, profile, failure, saving];
}
