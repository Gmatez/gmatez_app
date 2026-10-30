import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/di/core_providers.dart';
import '../../core/firebase/firebase_phone_auth_service.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/api_client.dart';
import '../../core/push/push_notifications.dart';
import '../../core/realtime/socket_io_realtime_service.dart';
import '../../core/storage/secure_store.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/presentation/state/auth_notifier.dart';
import '../../features/auth/presentation/state/auth_state.dart';
import '../../features/calls/presentation/state/active_call_notifier.dart';
import '../app.dart';
import '../config/app_config.dart';
import 'dart:async';

Future<Widget> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final logger = AppLogger(enabled: !config.isProduction);
  logger.info(
    'API configured',
    feature: 'network',
    data: {'apiBaseUrl': config.apiBaseUrl, 'realtimeUrl': config.realtimeUrl},
  );
  const storage = FlutterSecureStorage(aOptions: AndroidOptions());
  final tokenStore = SecureTokenStore(storage);
  final sessionBus = SessionExpiredBus();
  final suspendedBus = AccountSuspendedBus();

  final apiClient = ApiClient(
    config: config,
    tokenStore: tokenStore,
    logger: logger,
    onSessionExpired: sessionBus.fire,
    onAccountSuspended: suspendedBus.fire,
  );

  final authRepository = AuthRepositoryImpl(
    remote: AuthRemoteDataSource(apiClient),
    tokenStore: tokenStore,
  );
  final realtime = SocketIoRealtimeService(config: config, logger: logger);
  final incomingPushBus = IncomingPushBus();
  final push = PushNotificationService(
    api: apiClient,
    bus: incomingPushBus,
    logger: logger,
  );
  final firebasePhoneAuth = FirebasePhoneAuthService();

  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      appLoggerProvider.overrideWithValue(logger),
      tokenStoreProvider.overrideWithValue(tokenStore),
      apiClientProvider.overrideWithValue(apiClient),
      realtimeServiceProvider.overrideWithValue(realtime),
      incomingPushBusProvider.overrideWithValue(incomingPushBus),
      pushNotificationServiceProvider.overrideWithValue(push),
      firebasePhoneAuthServiceProvider.overrideWithValue(firebasePhoneAuth),
      authRepositoryProvider.overrideWithValue(authRepository),
      sessionExpiredBusProvider.overrideWithValue(sessionBus),
      accountSuspendedBusProvider.overrideWithValue(suspendedBus),
    ],
    child: const SessionLifecycle(child: GmatezApp()),
  );
}

class SessionLifecycle extends ConsumerStatefulWidget {
  const SessionLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionLifecycle> createState() => _SessionLifecycleState();
}

class _SessionLifecycleState extends ConsumerState<SessionLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(pushNotificationServiceProvider).start().catchError((
          Object error,
          StackTrace stack,
        ) {
          ref
              .read(appLoggerProvider)
              .error(
                'Push setup failed',
                feature: 'push',
                error: error,
                stackTrace: stack,
              );
        }),
      );
      ref.read(sessionExpiredBusProvider).handler = () {
        ref.read(authNotifierProvider.notifier).markSessionExpired();
      };
      ref.read(accountSuspendedBusProvider).handler = () {
        ref.read(authNotifierProvider.notifier).markAccountSuspended();
      };
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    final auth = ref.read(authNotifierProvider);
    if (auth.isAuthenticated || auth.isSuspended) {
      // Server-authoritative reconciliation after backgrounding.
      unawaited(ref.read(authNotifierProvider.notifier).refreshUser());
    }
    if (auth.isAuthenticated) {
      // restoreIfNeeded() only acts when nothing is held in memory yet;
      // resyncIfActive() re-validates a call already held in memory
      // against the server (it may have silently resolved while
      // backgrounded without this device catching every realtime event).
      unawaited(ref.read(activeCallProvider.notifier).restoreIfNeeded());
      unawaited(ref.read(activeCallProvider.notifier).resyncIfActive());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) async {
      final realtime = ref.read(realtimeServiceProvider);
      final store = ref.read(tokenStoreProvider);
      if (next.isAuthenticated) {
        final token = await store.readAccessToken();
        if (token != null && token.isNotEmpty) {
          await realtime.connect(token);
        }
        await ref.read(pushNotificationServiceProvider).registerCurrentUser();
        // Cold start recovery: if the app was killed mid-call and reopened
        // from the home-screen icon (not the call notification), this is
        // the only place that discovers a still-live server-side call.
        unawaited(ref.read(activeCallProvider.notifier).restoreIfNeeded());
        final pending = ref.read(incomingPushBusProvider).pendingCallId;
        if (pending != null) {
          await ref
              .read(activeCallProvider.notifier)
              .openIncomingFromPush(pending);
        }
      } else if (previous?.isAuthenticated ?? false) {
        await ref.read(pushNotificationServiceProvider).unregister();
        await realtime.disconnect();
      }
    });
    return widget.child;
  }
}
