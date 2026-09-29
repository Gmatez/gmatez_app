import 'app_environment.dart';

/// Compile-time and environment-aware configuration.
///
/// Dart-defines:
/// - `ENVIRONMENT` — development | test | staging | production
/// - `API_BASE_URL` — required for staging/production; optional for local
/// - `WS_BASE_URL` — optional realtime override
/// - `CALLING_MEDIA_PROVIDER` — mock | agora
///
/// Local / development defaults:
/// - API: `https://gmatez-api.onrender.com/api/v1` (shared staging)
/// - Local backend: `--dart-define=API_BASE_URL=http://127.0.0.1:43121/api/v1`
/// - Emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:43121/api/v1`
///
/// Production/staging refuse localhost and mock call media.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.realtimeUrl,
    required this.callingMediaProvider,
    required this.connectTimeout,
    required this.receiveTimeout,
  });

  final AppEnvironment environment;
  final String apiBaseUrl;
  final String realtimeUrl;
  final CallingMediaProviderKind callingMediaProvider;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  bool get isProduction => environment == AppEnvironment.production;
  bool get isStaging => environment == AppEnvironment.staging;
  bool get allowsMockProviders => environment.allowsMockProviders;
  bool get allowsMockCallMedia =>
      allowsMockProviders &&
      callingMediaProvider == CallingMediaProviderKind.mock;
  bool get allowsMockPayments => allowsMockProviders;

  factory AppConfig.fromEnvironment() {
    const envName = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'development',
    );
    const apiOverride = String.fromEnvironment('API_BASE_URL');
    const wsOverride = String.fromEnvironment('WS_BASE_URL');
    const mediaName = String.fromEnvironment(
      'CALLING_MEDIA_PROVIDER',
      defaultValue: '',
    );

    final environment = AppEnvironment.fromName(envName);
    final callingMediaProvider = _resolveMediaProvider(
      environment: environment,
      mediaName: mediaName,
    );
    final apiBaseUrl = resolveApiBaseUrl(
      environment: environment,
      apiOverride: apiOverride,
    );
    _assertSafeApiUrl(environment: environment, apiBaseUrl: apiBaseUrl);

    final realtimeUrl = wsOverride.isNotEmpty
        ? wsOverride
        : _defaultRealtimeUrl(apiBaseUrl);

    final remote = !_isLoopback(apiBaseUrl);
    return AppConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      realtimeUrl: realtimeUrl,
      callingMediaProvider: callingMediaProvider,
      connectTimeout: Duration(seconds: remote ? 90 : 15),
      receiveTimeout: Duration(seconds: remote ? 90 : 20),
    );
  }

  /// Visible for tests.
  static String resolveApiBaseUrl({
    required AppEnvironment environment,
    required String apiOverride,
  }) {
    if (apiOverride.isNotEmpty) {
      return apiOverride;
    }
    switch (environment) {
      case AppEnvironment.development:
      case AppEnvironment.test:
        // Shared staging API. Override locally with API_BASE_URL dart-define.
        return 'https://gmatez-api.onrender.com/api/v1';
      case AppEnvironment.staging:
      case AppEnvironment.production:
        throw StateError(
          'API_BASE_URL must be set via --dart-define for ${environment.name}',
        );
    }
  }

  /// @deprecated Use [resolveApiBaseUrl]
  static String resolveDevelopmentApiBaseUrl({
    required AppEnvironment environment,
    required String apiOverride,
  }) =>
      resolveApiBaseUrl(environment: environment, apiOverride: apiOverride);

  static CallingMediaProviderKind _resolveMediaProvider({
    required AppEnvironment environment,
    required String mediaName,
  }) {
    if (mediaName.isNotEmpty) {
      final kind = CallingMediaProviderKind.fromName(mediaName);
      if (!environment.allowsMockProviders &&
          kind == CallingMediaProviderKind.mock) {
        throw StateError(
          'CALLING_MEDIA_PROVIDER=mock is forbidden for ${environment.name}',
        );
      }
      return kind;
    }
    if (environment.allowsMockProviders) {
      return CallingMediaProviderKind.mock;
    }
    return CallingMediaProviderKind.agora;
  }

  /// Visible for tests and release validation.
  static void assertSafeApiUrl({
    required AppEnvironment environment,
    required String apiBaseUrl,
  }) {
    if (environment.allowsMockProviders) {
      return;
    }
    if (_isLoopback(apiBaseUrl)) {
      throw StateError(
        'Local/loopback API_BASE_URL is forbidden for ${environment.name}',
      );
    }
  }

  static CallingMediaProviderKind resolveCallingMediaProvider({
    required AppEnvironment environment,
    required String mediaName,
  }) =>
      _resolveMediaProvider(environment: environment, mediaName: mediaName);

  static void _assertSafeApiUrl({
    required AppEnvironment environment,
    required String apiBaseUrl,
  }) =>
      assertSafeApiUrl(environment: environment, apiBaseUrl: apiBaseUrl);

  static bool _isLoopback(String apiBaseUrl) {
    return apiBaseUrl.contains('127.0.0.1') ||
        apiBaseUrl.contains('10.0.2.2') ||
        apiBaseUrl.contains('localhost');
  }

  static String _defaultRealtimeUrl(String apiBaseUrl) {
    final uri = Uri.parse(apiBaseUrl);
    return uri.replace(path: '/ws', query: '', fragment: '').toString();
  }
}
