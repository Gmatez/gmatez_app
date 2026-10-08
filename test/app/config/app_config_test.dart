import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/app/config/app_config.dart';
import 'package:gmatez_app/app/config/app_environment.dart';

void main() {
  group('API base URL', () {
    test('development default points at staging API', () {
      expect(
        AppConfig.resolveApiBaseUrl(
          environment: AppEnvironment.development,
          apiOverride: '',
        ),
        'https://gmatez-api.onrender.com/api/v1',
      );
    });

    test('test default points at staging API', () {
      expect(
        AppConfig.resolveApiBaseUrl(
          environment: AppEnvironment.test,
          apiOverride: '',
        ),
        'https://gmatez-api.onrender.com/api/v1',
      );
    });

    test('explicit override is preserved including loopback', () {
      expect(
        AppConfig.resolveApiBaseUrl(
          environment: AppEnvironment.development,
          apiOverride: 'http://127.0.0.1:43121/api/v1',
        ),
        'http://127.0.0.1:43121/api/v1',
      );
    });

    test('explicit override is preserved including emulator alias', () {
      expect(
        AppConfig.resolveApiBaseUrl(
          environment: AppEnvironment.development,
          apiOverride: 'http://10.0.2.2:43121/api/v1',
        ),
        'http://10.0.2.2:43121/api/v1',
      );
    });

    test('staging/production require API_BASE_URL', () {
      expect(
        () => AppConfig.resolveApiBaseUrl(
          environment: AppEnvironment.production,
          apiOverride: '',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => AppConfig.resolveApiBaseUrl(
          environment: AppEnvironment.staging,
          apiOverride: '',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('production safety', () {
    test('production rejects loopback API URL', () {
      expect(
        () => AppConfig.assertSafeApiUrl(
          environment: AppEnvironment.production,
          apiBaseUrl: 'http://127.0.0.1:43121/api/v1',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => AppConfig.assertSafeApiUrl(
          environment: AppEnvironment.production,
          apiBaseUrl: 'http://10.0.2.2:43121/api/v1',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => AppConfig.assertSafeApiUrl(
          environment: AppEnvironment.production,
          apiBaseUrl: 'https://api.example.com/api/v1',
        ),
        returnsNormally,
      );
    });

    test('production/staging forbid mock call media', () {
      expect(
        () => AppConfig.resolveCallingMediaProvider(
          environment: AppEnvironment.production,
          mediaName: 'mock',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        AppConfig.resolveCallingMediaProvider(
          environment: AppEnvironment.production,
          mediaName: '',
        ),
        CallingMediaProviderKind.agora,
      );
      expect(
        AppConfig.resolveCallingMediaProvider(
          environment: AppEnvironment.development,
          mediaName: '',
        ),
        CallingMediaProviderKind.agora,
      );
      expect(
        AppConfig.resolveCallingMediaProvider(
          environment: AppEnvironment.development,
          mediaName: 'mock',
        ),
        CallingMediaProviderKind.mock,
      );
    });
  });
}
