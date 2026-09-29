import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/core/errors/app_failure.dart';
import 'package:gmatez_app/core/pagination/cursor_page.dart';
import 'package:gmatez_app/core/utils/result.dart';
import 'package:gmatez_app/features/discovery/presentation/state/discovery_notifier.dart';
import 'package:gmatez_app/features/discovery/presentation/state/discovery_state.dart';

import '../../fakes/fake_discovery_profile_repositories.dart';

void main() {
  test('loads discovery users into a success state', () async {
    final discovery = FakeDiscoveryRepository();
    final profiles = FakeProfileRepository();
    final container = ProviderContainer(
      overrides: [
        discoveryRepositoryProvider.overrideWithValue(discovery),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
    addTearDown(container.dispose);

    container.read(discoveryNotifierProvider.notifier);
    await container.read(discoveryNotifierProvider.notifier).loadInitial();

    final state = container.read(discoveryNotifierProvider);
    expect(state.status, DiscoveryStatus.success);
    expect(state.users, hasLength(2));
    expect(discovery.feedCalls, greaterThan(0));
  });

  test('maps an API error to the error state', () async {
    final discovery = FakeDiscoveryRepository(
      feedResult: const Failure(
        AppFailure(
          kind: FailureKind.server,
          message: 'Something went wrong. Please try again.',
          code: 'INTERNAL',
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        discoveryRepositoryProvider.overrideWithValue(discovery),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(discoveryNotifierProvider.notifier).loadInitial();
    expect(
      container.read(discoveryNotifierProvider).status,
      DiscoveryStatus.error,
    );
  });

  test('empty pages become the empty state', () async {
    final discovery = FakeDiscoveryRepository(
      feedResult: const Success(CursorPage(items: [])),
    );
    final container = ProviderContainer(
      overrides: [
        discoveryRepositoryProvider.overrideWithValue(discovery),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(discoveryNotifierProvider.notifier).loadInitial();
    expect(
      container.read(discoveryNotifierProvider).status,
      DiscoveryStatus.empty,
    );
  });

  test('ignores stale search responses', () async {
    final discovery = FakeDiscoveryRepository();
    final container = ProviderContainer(
      overrides: [
        discoveryRepositoryProvider.overrideWithValue(discovery),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(discoveryNotifierProvider.notifier);
    await notifier.loadInitial();
    notifier.setQuery('Bo');
    notifier.setQuery('Bob');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(discovery.lastQuery?.search, 'Bob');
  });
}
