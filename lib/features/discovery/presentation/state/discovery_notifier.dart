import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../../core/pagination/cursor_page.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/utils/result.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../data/repositories/discovery_repository_impl.dart';
import '../../domain/repositories/discovery_repository.dart';
import '../../../profile/data/repositories/profile_repository_impl.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import 'discovery_state.dart';

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepositoryImpl(
    DiscoveryRemoteDataSource(ref.watch(apiClientProvider)),
  );
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(
    ProfileRemoteDataSource(ref.watch(apiClientProvider)),
  );
});

class DiscoveryNotifier extends Notifier<DiscoveryState> {
  final _debouncer = Debouncer();

  DiscoveryRepository get _discovery => ref.read(discoveryRepositoryProvider);
  ProfileRepository get _profiles => ref.read(profileRepositoryProvider);

  @override
  DiscoveryState build() {
    ref.onDispose(_debouncer.dispose);
    return const DiscoveryState.loading();
  }

  Future<void> loadInitial() async {
    await _profiles.heartbeat();
    await _fetch(reset: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(status: DiscoveryStatus.refreshing);
    await _profiles.heartbeat();
    await _fetch(reset: true);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore || state.isBusy) {
      return;
    }
    state = state.copyWith(loadingMore: true);
    await _fetch(reset: false);
  }

  void setQuery(String value) {
    state = state.copyWith(query: value);
    _debouncer.run(() {
      Future<void>.microtask(() => _fetch(reset: true));
    });
  }

  Future<void> setLanguage(String? language) async {
    state = state.copyWith(
      language: language,
      clearLanguage: language == null || language.isEmpty,
    );
    await _fetch(reset: true);
  }

  Future<void> setOnlineOnly(bool value) async {
    state = state.copyWith(onlineOnly: value);
    await _fetch(reset: true);
  }

  Future<void> setCallType(String? callType) async {
    state = state.copyWith(
      callType: callType,
      clearCallType: callType == null || callType.isEmpty,
    );
    await _fetch(reset: true);
  }

  Future<void> _fetch({required bool reset}) async {
    final requestId = state.requestId + 1;
    if (reset) {
      final keepUsers =
          state.status == DiscoveryStatus.refreshing && state.users.isNotEmpty;
      state = state.copyWith(
        requestId: requestId,
        status: keepUsers
            ? DiscoveryStatus.refreshing
            : DiscoveryStatus.loading,
        users: keepUsers ? state.users : const [],
        clearCursor: true,
        clearFailure: true,
        loadingMore: false,
      );
    } else {
      state = state.copyWith(requestId: requestId);
    }

    final query = DiscoveryQuery(
      limit: 20,
      cursor: reset ? null : state.nextCursor,
      search: state.query,
      language: state.language,
      onlineOnly: state.onlineOnly,
      callType: state.callType,
    );
    final searching = (state.query.trim().length >= 2);
    final result = searching
        ? await _discovery.search(query)
        : await _discovery.feed(query);

    if (state.requestId != requestId) {
      return;
    }

    switch (result) {
      case Failure<CursorPage<UserProfile>>(:final failure):
        state = state.copyWith(
          status: DiscoveryStatus.error,
          failure: failure,
          loadingMore: false,
        );
      case Success<CursorPage<UserProfile>>(:final value):
        final users = reset ? value.items : [...state.users, ...value.items];
        state = state.copyWith(
          status: users.isEmpty
              ? DiscoveryStatus.empty
              : DiscoveryStatus.success,
          users: users,
          nextCursor: value.nextCursor,
          clearCursor: !value.hasMore,
          loadingMore: false,
          clearFailure: true,
        );
    }
  }
}

final discoveryNotifierProvider =
    NotifierProvider<DiscoveryNotifier, DiscoveryState>(DiscoveryNotifier.new);
