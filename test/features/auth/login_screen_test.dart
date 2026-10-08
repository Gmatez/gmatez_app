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
    await tester.pumpWidget(_loginApp(fake));

    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Phone number is required.'), findsOneWidget);
    expect(fake.requestOtpCalls, 0);
  });

  testWidgets('sends the entered phone number and opens otp', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_loginApp(fake));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '9876543210');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(fake.requestOtpCalls, 1);
    expect(find.text('Enter verification code'), findsOneWidget);
    expect(find.text('Phone number is required.'), findsNothing);
  });

  testWidgets('stays within bounds on a small phone with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    final fake = FakeAuthRepository();
    await tester.pumpWidget(_loginApp(fake));
    await tester.pump();
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '9876543210');
    await tester.ensureVisible(find.text('Continue'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);
  });
}

Widget _loginApp(FakeAuthRepository fake) {
  return ProviderScope(
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
  );
}
