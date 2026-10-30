import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../app/config/app_config.dart';
import '../logging/app_logger.dart';
import 'realtime_service.dart';

class SocketIoRealtimeService implements RealtimeService {
  SocketIoRealtimeService({
    required AppConfig config,
    required AppLogger logger,
  }) : _config = config,
       _logger = logger;

  final AppConfig _config;
  final AppLogger _logger;

  io.Socket? _socket;
  Timer? _presenceTimer;
  int _attempt = 0;

  final _connection = StreamController<RealtimeConnectionState>.broadcast();
  final _events = StreamController<RealtimeEvent>.broadcast();

  @override
  Stream<RealtimeConnectionState> get connection => _connection.stream;

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Future<void> connect(String accessToken) async {
    await disconnect();
    _connection.add(RealtimeConnectionState.connecting);

    final socket = io.io(
      _config.realtimeUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .enableReconnection()
          .setReconnectionAttempts(64)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      _attempt = 0;
      _connection.add(RealtimeConnectionState.connected);
      _logger.info('Realtime connected', feature: 'realtime');
      _startPresencePing(socket);
    });
    socket.onDisconnect((_) {
      _connection.add(RealtimeConnectionState.disconnected);
      _presenceTimer?.cancel();
    });
    socket.onReconnect((_) {
      _connection.add(RealtimeConnectionState.connected);
    });
    socket.onReconnectAttempt((_) {
      _attempt += 1;
      _connection.add(RealtimeConnectionState.reconnecting);
      _logger.debug(
        'Realtime reconnect attempt',
        feature: 'realtime',
        data: {'attempt': _attempt},
      );
    });
    socket.onConnectError((error) {
      _logger.warning(
        'Realtime connect error',
        feature: 'realtime',
        data: {'error': error.toString()},
      );
    });

    const knownEvents = [
      'call.initiated',
      'call.ringing',
      'call.accepted',
      'call.connecting',
      'call.rejected',
      'call.cancelled',
      'call.timeout',
      'call.connected',
      'call.ended',
      'call.failed',
      'call.peer-disconnected',
      'call.peer-reconnected',
      'presence.updated',
      'notification.received',
      'wallet.updated',
      'message.created',
      'message.read',
      'message.typing',
      'host.availability.updated',
    ];
    for (final event in knownEvents) {
      socket.on(event, (data) {
        _events.add(RealtimeEvent(name: event, payload: _asMap(data)));
      });
    }

    _socket = socket;
    socket.connect();
  }

  @override
  void emit(String event, [Object? data]) {
    _socket?.emit(event, data);
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {'raw': data};
  }

  void _startPresencePing(io.Socket socket) {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      socket.emit('presence.ping');
    });
  }

  @override
  Future<void> disconnect() async {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    _socket?.dispose();
    _socket = null;
    _connection.add(RealtimeConnectionState.disconnected);
  }

  @override
  void dispose() {
    unawaited(disconnect());
    unawaited(_connection.close());
    unawaited(_events.close());
  }
}
