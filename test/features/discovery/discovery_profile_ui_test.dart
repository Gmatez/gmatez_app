import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/core/calling/call_media_provider.dart';
import 'package:gmatez_app/core/di/core_providers.dart';
import 'package:gmatez_app/core/errors/app_failure.dart';
import 'package:gmatez_app/core/pagination/cursor_page.dart';
import 'package:gmatez_app/core/utils/result.dart';
import 'package:gmatez_app/features/calls/presentation/state/active_call_notifier.dart';
import 'package:gmatez_app/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:gmatez_app/features/discovery/presentation/state/discovery_notifier.dart';
import 'package:gmatez_app/features/profile/domain/entities/user_profile.dart';
import 'package:gmatez_app/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:gmatez_app/features/profile/presentation/screens/public_profile_screen.dart';
import 'package:go_router/go_router.dart';

import '../../fakes/fake_calling.dart';
import '../../fakes/fake_discovery_profile_repositories.dart';

void main() {
  // DiscoveryUserTile/PublicProfileScreen both watch activeCallProvider's
  // busy flag (double-submit guard), which means ActiveCallNotifier.build()
  // runs for any test that renders them — it needs these three providers.
  final callingOverrides = [
    realtimeServiceProvider.overrideWithValue(FakeRealtimeService()),
    callMediaProvider.overrideWithValue(MockCallMediaProvider()),
    callRepositoryProvider.overrideWithValue(FakeCallRepository()),
  ];

  testWidgets('discovery renders users from the repository', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryRepositoryProvider.overrideWithValue(
            FakeDiscoveryRepository(),
          ),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          ...callingOverrides,
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/discover',
            routes: [
              GoRoute(
                path: '/discover',
                builder: (_, _) => const DiscoveryScreen(),
              ),
              GoRoute(
                path: '/profile/:userId',
                builder: (_, _) => const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Carol'), findsOneWidget);
  });

  testWidgets('discovery shows an empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryRepositoryProvider.overrideWithValue(
            FakeDiscoveryRepository(
              feedResult: const Success(CursorPage(items: [])),
            ),
          ),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        ],
        child: const MaterialApp(home: DiscoveryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No hosts to discover yet.'), findsOneWidget);
  });

  testWidgets('discovery shows an error state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryRepositoryProvider.overrideWithValue(
            FakeDiscoveryRepository(
              feedResult: const Failure(
                AppFailure(
                  kind: FailureKind.offline,
                  message:
                      'No internet connection. Check your network and try again.',
                ),
              ),
            ),
          ),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        ],
        child: const MaterialApp(home: DiscoveryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No internet connection'), findsOneWidget);
  });

  testWidgets('public profile renders backend fields', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(
              publicProfile: const UserProfile(
                userId: 'user-2',
                displayName: 'Bob',
                bio: 'Say hello',
                gender: 'MALE',
                language: 'en',
                ratePerMinuteCents: 100,
                online: true,
                availableForCall: true,
              ),
            ),
          ),
          ...callingOverrides,
        ],
        child: const MaterialApp(home: PublicProfileScreen(userId: 'user-2')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsWidgets);
    expect(find.text('Say hello'), findsOneWidget);
    expect(find.text('Voice call'), findsOneWidget);
  });

  testWidgets('edit profile validates a short display name', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          discoveryRepositoryProvider.overrideWithValue(
            FakeDiscoveryRepository(),
          ),
        ],
        child: const MaterialApp(home: EditProfileScreen()),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'A');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(find.text('Name must be at least 2 characters.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
