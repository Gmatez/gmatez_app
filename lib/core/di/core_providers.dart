import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../firebase/firebase_phone_auth_service.dart';
import '../logging/app_logger.dart';
import '../network/api_client.dart';
import '../network/token_store.dart';
import '../push/push_notifications.dart';
import '../realtime/realtime_service.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('Override appConfigProvider in bootstrap');
});

final appLoggerProvider = Provider<AppLogger>((ref) {
  throw UnimplementedError('Override appLoggerProvider in bootstrap');
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  throw UnimplementedError('Override tokenStoreProvider in bootstrap');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('Override apiClientProvider in bootstrap');
});

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  throw UnimplementedError('Override realtimeServiceProvider in bootstrap');
});

final incomingPushBusProvider = Provider<IncomingPushBus>((ref) {
  return IncomingPushBus();
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  throw UnimplementedError(
    'Override pushNotificationServiceProvider in bootstrap',
  );
});

final firebasePhoneAuthServiceProvider = Provider<FirebasePhoneAuthService>((
  ref,
) {
  throw UnimplementedError(
    'Override firebasePhoneAuthServiceProvider in bootstrap',
  );
});

class SessionExpiredBus {
  void Function()? handler;

  void fire() => handler?.call();
}

final sessionExpiredBusProvider = Provider<SessionExpiredBus>((ref) {
  return SessionExpiredBus();
});

class AccountSuspendedBus {
  void Function()? handler;

  void fire() => handler?.call();
}

final accountSuspendedBusProvider = Provider<AccountSuspendedBus>((ref) {
  return AccountSuspendedBus();
});
