import 'package:equatable/equatable.dart';

enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class RealtimeEvent extends Equatable {
  const RealtimeEvent({required this.name, required this.payload});

  final String name;
  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => [name, payload];
}

/// Single app-wide realtime client. Socket.IO namespace `/ws`.
abstract class RealtimeService {
  Stream<RealtimeConnectionState> get connection;
  Stream<RealtimeEvent> get events;

  Future<void> connect(String accessToken);
  Future<void> disconnect();
  void emit(String event, [Object? data]);
  void dispose();
}
