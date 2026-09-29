import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gmatez_app/features/host/presentation/state/host_onboarding_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('onboarding requires agreements languages bio and display name', () {
    const incomplete = HostOnboardingState();
    expect(incomplete.canSubmit, isFalse);

    const complete = HostOnboardingState(
      displayName: 'Ada',
      bio: 'Ready to listen carefully',
      languages: ['English'],
      interests: ['Music'],
      agreementAccepted: true,
      guidelinesAccepted: true,
      termsAccepted: true,
      privacyAccepted: true,
    );
    expect(complete.canSubmit, isTrue);
  });

  test('toggle language updates draft', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(hostOnboardingProvider.notifier);
    notifier.toggleLanguage('Hindi');
    expect(container.read(hostOnboardingProvider).languages, contains('Hindi'));
    await notifier.persistDraft();
  });

  test('onboarding draft round-trips through local storage', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(hostOnboardingProvider.notifier);
    notifier.patch(
      const HostOnboardingState(
        displayName: 'Ada',
        bio: 'Ready to listen carefully',
        step: 2,
        agreementAccepted: true,
      ),
    );
    await notifier.persistDraft();

    final other = ProviderContainer();
    addTearDown(other.dispose);
    await other.read(hostOnboardingProvider.notifier).restoreDraft();
    final restored = other.read(hostOnboardingProvider);
    expect(restored.displayName, 'Ada');
    expect(restored.step, 2);
    expect(restored.agreementAccepted, isTrue);
  });
}
