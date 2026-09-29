import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../../discovery/presentation/state/discovery_notifier.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class MyProfileNotifier extends Notifier<ProfileViewState> {
  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  ProfileViewState build() {
    return const ProfileViewState.loading();
  }

  Future<void> load() async {
    state = state.copyWith(
      status: ProfileViewStatus.loading,
      clearFailure: true,
    );
    final result = await _repository.getMine();
    state = switch (result) {
      Success<UserProfile>(:final value) => ProfileViewState(
        status: ProfileViewStatus.success,
        profile: value,
      ),
      Failure<UserProfile>(:final failure) => ProfileViewState(
        status: ProfileViewStatus.error,
        failure: failure,
      ),
    };
  }

  Future<bool> save(ProfileUpdate update) async {
    if (state.saving) {
      return false;
    }
    state = state.copyWith(saving: true, clearFailure: true);
    final result = await _repository.updateMine(update);
    switch (result) {
      case Failure<UserProfile>(:final failure):
        state = state.copyWith(
          saving: false,
          status: ProfileViewStatus.error,
          failure: failure,
        );
        return false;
      case Success<UserProfile>(:final value):
        state = ProfileViewState(
          status: ProfileViewStatus.success,
          profile: value,
        );
        return true;
    }
  }
}

final myProfileNotifierProvider =
    NotifierProvider<MyProfileNotifier, ProfileViewState>(
      MyProfileNotifier.new,
    );

final publicProfileProvider = FutureProvider.autoDispose
    .family<Result<UserProfile>, String>((ref, userId) {
      return ref.watch(profileRepositoryProvider).getPublic(userId);
    });
