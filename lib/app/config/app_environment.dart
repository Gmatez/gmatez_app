enum AppEnvironment {
  development,
  test,
  staging,
  production;

  static AppEnvironment fromName(String value) {
    return AppEnvironment.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AppEnvironment.development,
    );
  }

  bool get isLocal =>
      this == AppEnvironment.development || this == AppEnvironment.test;

  bool get allowsMockProviders => isLocal;
}

/// How call media (RTC) is provided on this build.
enum CallingMediaProviderKind {
  mock,
  agora;

  static CallingMediaProviderKind fromName(String value) {
    return CallingMediaProviderKind.values.firstWhere(
      (item) => item.name == value,
      orElse: () => throw ArgumentError(
        'Unknown CALLING_MEDIA_PROVIDER="$value" (expected mock|agora)',
      ),
    );
  }
}
