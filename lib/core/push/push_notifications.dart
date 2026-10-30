import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/api_paths.dart';
import '../logging/app_logger.dart';
import '../network/api_client.dart';

const incomingCallChannelId = 'gmatez_incoming_call';
const incomingCallSound = 'incoming_call';
const generalChannelId = 'general';

const _callSound = RawResourceAndroidNotificationSound(incomingCallSound);

/// Call ids delivered by FCM while the app was backgrounded or closed.
class IncomingPushBus {
  String? pendingCallId;
  final _calls = StreamController<String>.broadcast();

  Stream<String> get calls => _calls.stream;

  void add(String callId) {
    if (callId.isEmpty) {
      return;
    }
    pendingCallId = callId;
    if (!_calls.isClosed) {
      _calls.add(callId);
    }
  }

  void clear(String callId) {
    if (pendingCallId == callId) {
      pendingCallId = null;
    }
  }
}

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  final data = message.data;
  if (data['type'] != 'incoming_call') {
    return;
  }
  try {
    await _showIncomingCallNotification(data);
  } catch (_) {}
}

Future<void> _ensureChannels({
  void Function(NotificationResponse response)? onTap,
}) async {
  const android = AndroidInitializationSettings('@drawable/ic_stat_notify');
  const ios = DarwinInitializationSettings();
  await localNotifications.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: onTap,
  );
  final androidPlugin = localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.deleteNotificationChannel('incoming_calls');
  await androidPlugin?.deleteNotificationChannel('incoming_call_ring');
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      incomingCallChannelId,
      'Incoming calls',
      description: 'Rings when someone calls you',
      importance: Importance.max,
      playSound: true,
      sound: _callSound,
    ),
  );
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      generalChannelId,
      'General',
      description: 'Messages and account updates',
      importance: Importance.high,
    ),
  );
}

Future<void> _showIncomingCallNotification(Map<String, dynamic> data) async {
  await _ensureChannels();
  final callId = data['callId'] as String? ?? '';
  if (callId.isEmpty) {
    return;
  }
  final title = data['title'] as String? ?? 'Incoming call';
  final body = data['body'] as String? ?? 'You have an incoming call';
  await localNotifications.show(
    callId.hashCode,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        incomingCallChannelId,
        'Incoming calls',
        channelDescription: 'Rings when someone calls you',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        visibility: NotificationVisibility.public,
        playSound: true,
        sound: _callSound,
        enableVibration: true,
        // Launches the app over the lock screen instead of showing an
        // easy-to-miss heads-up banner. Requires USE_FULL_SCREEN_INTENT
        // (manifest) + android:showWhenLocked/turnScreenOn on MainActivity
        // (manifest) + a data-only FCM payload (backend) to actually fire
        // reliably from a backgrounded/killed app.
        fullScreenIntent: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    ),
    payload: callId,
  );
}

/// Dismiss the native incoming-call notification/ringtone for [callId].
/// Call this on every resolution path (accept, reject, resolved on another
/// device, terminal status) — otherwise a late-delivered push can keep
/// ringing/displaying for a call that's already been dealt with.
Future<void> cancelIncomingCallNotification(String callId) async {
  if (callId.isEmpty) {
    return;
  }
  try {
    await localNotifications.cancel(callId.hashCode);
  } catch (_) {
    // Best-effort.
  }
}

class PushNotificationService {
  PushNotificationService({
    required ApiClient api,
    required IncomingPushBus bus,
    required AppLogger logger,
  }) : _api = api,
       _bus = bus,
       _logger = logger;

  final ApiClient _api;
  final IncomingPushBus _bus;
  final AppLogger _logger;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  String? _token;

  void dispose() {
    unawaited(_tokenRefresh?.cancel());
    unawaited(_foreground?.cancel());
    unawaited(_opened?.cancel());
    _tokenRefresh = null;
    _foreground = null;
    _opened = null;
  }

  Future<void> start() async {
    await _ensureChannels(
      onTap: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _bus.add(payload);
        }
      },
    );
    final androidPlugin = localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    final messaging = FirebaseMessaging.instance;
    if (!Platform.isAndroid) {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    }
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    _foreground ??= FirebaseMessaging.onMessage.listen(_onMessage);
    _opened ??= FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _dispatch(initial.data);
    }
    final launch = await localNotifications.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true &&
        payload != null &&
        payload.isNotEmpty) {
      _bus.add(payload);
    }
  }

  Future<void> registerCurrentUser() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    _token = token;
    final platform = Platform.isIOS ? 'ios' : 'android';
    final result = await _api.post<void>(
      ApiPaths.notificationDevices,
      body: {'token': token, 'platform': platform},
      parser: (_) {},
    );
    _logger.info(
      'Device push token registered',
      feature: 'push',
      data: {'ok': result.isSuccess, 'platform': platform},
    );
    _tokenRefresh ??= FirebaseMessaging.instance.onTokenRefresh.listen((
      next,
    ) async {
      _token = next;
      await _api.post<void>(
        ApiPaths.notificationDevices,
        body: {'token': next, 'platform': platform},
        parser: (_) {},
      );
    });
  }

  Future<void> unregister() async {
    final token = _token;
    _token = null;
    if (token == null || token.isEmpty) {
      return;
    }
    await _api.delete<void>(
      '${ApiPaths.notificationDevices}/${Uri.encodeComponent(token)}',
      parser: (_) {},
    );
  }

  void _onMessage(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      // Foreground: the in-app IncomingCallHost overlay (driven by
      // _dispatch below) is the UI — showing the native heads-up
      // notification too would duplicate it. The native notification is
      // for background/killed state only (firebaseMessagingBackgroundHandler).
      _dispatch(data);
      return;
    }
    final title = message.notification?.title ?? data['title'] as String?;
    final body = message.notification?.body ?? data['body'] as String?;
    if (title != null && title.isNotEmpty) {
      unawaited(
        localNotifications.show(
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              generalChannelId,
              'General',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_stat_notify',
            ),
          ),
        ),
      );
    }
  }

  void _onOpened(RemoteMessage message) {
    _dispatch(message.data);
  }

  void _dispatch(Map<String, dynamic> data) {
    if (data['type'] == 'incoming_call') {
      final callId = data['callId'] as String? ?? '';
      _bus.add(callId);
    }
  }
}
