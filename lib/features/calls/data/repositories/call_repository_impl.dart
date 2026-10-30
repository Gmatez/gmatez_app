import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/pagination/cursor_page.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/call_session.dart';
import '../../domain/repositories/call_repository.dart';

class CallRepositoryImpl implements CallRepository {
  CallRepositoryImpl(this._client);

  final ApiClient _client;

  /// Fastify rejects `Content-Type: application/json` with an empty body.
  static const _emptyJson = <String, dynamic>{};

  @override
  Future<Result<CallSession>> create({
    required String calleeId,
    required String callType,
    required String idempotencyKey,
  }) {
    return _client.post(
      ApiPaths.calls,
      body: {
        'calleeId': calleeId,
        'callType': callType,
        'idempotencyKey': idempotencyKey,
      },
      parser: _parse,
    );
  }

  @override
  Future<Result<CallSession>> getById(String id) {
    return _client.get(ApiPaths.call(id), parser: _parse);
  }

  @override
  Future<Result<CursorPage<CallSession>>> history({String? cursor}) {
    return _client.get(
      ApiPaths.calls,
      query: {'cursor': ?cursor},
      parser: (data) => CursorPage.fromJson(data, _parse),
    );
  }

  @override
  Future<Result<CallSession>> accept(String id) {
    return _client.post(
      ApiPaths.callAccept(id),
      body: _emptyJson,
      parser: _parse,
    );
  }

  @override
  Future<Result<CallSession>> reject(String id) {
    return _client.post(
      ApiPaths.callReject(id),
      body: _emptyJson,
      parser: _parse,
    );
  }

  @override
  Future<Result<CallSession>> cancel(String id) {
    return _client.post(
      ApiPaths.callCancel(id),
      body: _emptyJson,
      parser: _parse,
    );
  }

  @override
  Future<Result<CallSession>> end(String id) {
    return _client.post(ApiPaths.callEnd(id), body: _emptyJson, parser: _parse);
  }

  @override
  Future<Result<void>> heartbeat(String id) {
    return _client.post(
      ApiPaths.callHeartbeat(id),
      body: _emptyJson,
      parser: (_) {},
    );
  }

  @override
  Future<Result<CallRtcCredentials>> rtcToken(String id) {
    return _client.post(
      ApiPaths.callRtcToken(id),
      body: _emptyJson,
      parser: (data) => CallRtcCredentials.fromJson(
        data is Map ? Map<String, dynamic>.from(data) : const {},
      ),
    );
  }

  @override
  Future<Result<CallSession>> rtcJoined(String id) {
    return _client.post(
      ApiPaths.callRtcJoined(id),
      body: _emptyJson,
      parser: _parse,
    );
  }

  @override
  Future<Result<CallSession>> rtcFailed(String id, {String? reason}) {
    return _client.post(
      ApiPaths.callRtcFailed(id),
      body: {'reason': ?reason},
      parser: _parse,
    );
  }

  CallSession _parse(dynamic data) {
    return CallSession.fromJson(
      data is Map<String, dynamic> ? data : const <String, dynamic>{},
    );
  }
}
