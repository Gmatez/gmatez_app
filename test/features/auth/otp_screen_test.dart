import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/app/config/app_config.dart';
import 'package:gmatez_app/app/config/app_environment.dart';
import 'package:gmatez_app/core/di/core_providers.dart';
import 'package:gmatez_app/core/logging/app_logger.dart';
import 'package:gmatez_app/core/utils/result.dart';
import 'package:gmatez_app/features/auth/domain/entities/session.dart';
import 'package:gmatez_app/features/auth/presentation/screens/otp_screen.dart';
import 'package:gmatez_app/features/auth/presentation/state/auth_notifier.dart';
import 'package:go_router/go_router.dart';

import '../../fakes/fake_auth_repository.dart';

void main() {
  testWidgets('OTP screen shows resend cooldown after request', (tester) async {
    final fake = FakeAuthRepository(
      requestOtpResult: const Success(
        OtpChallenge(expiresInSeconds: 300, resendAvailableInSeconds: 60),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.development,
              apiBaseUrl: 'http://127.0.0.1:43121/api/v1',
              realtimeUrl: 'http://127.0.0.1:43121/ws',
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
            initialLocation: '/otp',
            routes: [
              GoRoute(path: '/otp', builder: (_, _) => const OtpScreen()),
              GoRoute(path: '/login', builder: (_, _) => const SizedBox()),
            ],
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OtpScreen)),
    );
    await container
        .read(authNotifierProvider.notifier)
        .requestPhoneOtp('+919876543210');
    await tester.pump();

    expect(find.textContaining('Resend in'), findsOneWidget);
    expect(find.textContaining('Verify'), findsOneWidget);
  });
}
