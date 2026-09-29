import '../../../../core/pagination/cursor_page.dart';
import '../../../../core/utils/result.dart';
import '../entities/call_session.dart';

abstract class CallRepository {
  Future<Result<CallSession>> create({
    required String calleeId,
    required String callType,
    required String idempotencyKey,
  });

  Future<Result<CallSession>> getById(String id);
  Future<Result<CursorPage<CallSession>>> history({String? cursor});
  Future<Result<CallSession>> accept(String id);
  Future<Result<CallSession>> reject(String id);
  Future<Result<CallSession>> cancel(String id);
  Future<Result<CallSession>> end(String id);
  Future<Result<void>> heartbeat(String id);
  Future<Result<CallRtcCredentials>> rtcToken(String id);
  Future<Result<CallSession>> rtcJoined(String id);
  Future<Result<CallSession>> rtcFailed(String id, {String? reason});
}
