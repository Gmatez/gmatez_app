import 'dart:async';

import 'package:gmatez_app/core/pagination/cursor_page.dart';
import 'package:gmatez_app/core/realtime/realtime_service.dart';
import 'package:gmatez_app/core/utils/result.dart';
import 'package:gmatez_app/features/calls/domain/entities/call_session.dart';
import 'package:gmatez_app/features/calls/domain/repositories/call_repository.dart';

/// Minimal fake used anywhere a widget tree ends up building
/// `activeCallProvider` (any screen that watches call state or renders a
/// call-start button) — without this, `ActiveCallNotifier.build()` throws
/// on the real `realtimeServiceProvider` placeholder.
class FakeRealtimeService implements RealtimeService {
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _connection = StreamController<RealtimeConnectionState>.broadcast();

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Stream<RealtimeConnectionState> get connection => _connection.stream;

  void push(String name, Map<String, dynamic> payload) {
    _events.add(RealtimeEvent(name: name, payload: payload));
  }

  @override
  Future<void> connect(String accessToken) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void emit(String event, [Object? data]) {}

  @override
  void dispose() {
    unawaited(_events.close());
    unawaited(_connection.close());
  }
}

/// Fake `CallRepository`. Every method throws by default (matching the
/// existing `FakeAuthRepository`/`FakeDiscoveryRepository` style) unless a
/// result is configured — set `createResult` etc. per-test.
class FakeCallRepository implements CallRepository {
  int createCalls = 0;
  Result<CallSession>? createResult;

  @override
  Future<Result<CallSession>> create({
    required String calleeId,
    required String callType,
    required String idempotencyKey,
  }) async {
    createCalls += 1;
    final configured = createResult;
    if (configured != null) {
      return configured;
    }
    throw UnimplementedError();
  }

  @override
  Future<Result<CallSession>> getById(String id) => throw UnimplementedError();

  @override
  Future<Result<CursorPage<CallSession>>> history({String? cursor}) =>
      throw UnimplementedError();

  @override
  Future<Result<CallSession>> accept(String id) => throw UnimplementedError();

  @override
  Future<Result<CallSession>> reject(String id) => throw UnimplementedError();

  @override
  Future<Result<CallSession>> cancel(String id) => throw UnimplementedError();

  @override
  Future<Result<CallSession>> end(String id) => throw UnimplementedError();

  @override
  Future<Result<void>> heartbeat(String id) => throw UnimplementedError();

  @override
  Future<Result<CallRtcCredentials>> rtcToken(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<CallSession>> rtcJoined(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<CallSession>> rtcFailed(String id, {String? reason}) =>
      throw UnimplementedError();
}
