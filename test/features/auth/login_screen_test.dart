import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/app/config/app_config.dart';
import 'package:gmatez_app/app/config/app_environment.dart';
import 'package:gmatez_app/core/di/core_providers.dart';
import 'package:gmatez_app/core/logging/app_logger.dart';
import 'package:gmatez_app/features/auth/presentation/screens/login_screen.dart';
import 'package:gmatez_app/features/auth/presentation/state/auth_notifier.dart';
import 'package:go_router/go_router.dart';

import '../../fakes/fake_auth_repository.dart';

void main() {
  testWidgets('shows validation when continuing without a phone number', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.development,
              apiBaseUrl: 'http://localhost/api/v1',
              realtimeUrl: 'http://localhost/ws',
              callingMediaProvider: CallingMediaProviderKind.mock,
              connectTimeout: Duration(seconds: 1),
              receiveTimeout: Duration(seconds: 1),
            ),
          ),
          appLoggerProvider.overrideWithValue(AppLogger(enabled: false)),
          authRepositoryProvider.overrideWithValue(fake),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/login',
            routes: [
              GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
              GoRoute(path: '/otp', builder: (_, _) => const SizedBox()),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Phone number is required.'), findsOneWidget);
    expect(fake.requestOtpCalls, 0);
  });
}
