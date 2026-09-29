import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/core/errors/app_failure.dart';
import 'package:gmatez_app/core/utils/result.dart';
import 'package:gmatez_app/features/discovery/presentation/state/discovery_notifier.dart';
import 'package:gmatez_app/features/profile/domain/entities/user_profile.dart';
import 'package:gmatez_app/features/profile/presentation/state/profile_notifier.dart';
import 'package:gmatez_app/features/profile/presentation/state/profile_state.dart';

import '../../fakes/fake_discovery_profile_repositories.dart';

void main() {
  test('loads the current profile', () async {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(myProfileNotifierProvider.notifier).load();
    final state = container.read(myProfileNotifierProvider);
    expect(state.status, ProfileViewStatus.success);
    expect(state.profile?.displayName, 'Alice');
  });

  test('prevents overlapping saves and maps failures', () async {
    final fake = FakeProfileRepository(
      updateResult: const Failure(
        AppFailure(
          kind: FailureKind.validation,
          message: 'Please check the information you entered.',
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(myProfileNotifierProvider.notifier);
    await notifier.load();
    final ok = await notifier.save(
      const ProfileUpdate(displayName: 'Alice Updated'),
    );
    expect(ok, isFalse);
    expect(fake.updateCalls, 1);
    expect(
      container.read(myProfileNotifierProvider).status,
      ProfileViewStatus.error,
    );
  });
}
