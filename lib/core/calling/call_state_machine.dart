import 'call_status.dart';

/// Mirrors `src/modules/calling/call-state.machine.ts`.
/// The backend remains authoritative; this prevents illegal local UI jumps.
abstract final class CallStateMachine {
  static const allowed = <CallStatus, Set<CallStatus>>{
    CallStatus.initiated: {
      CallStatus.ringing,
      CallStatus.cancelled,
      CallStatus.failed,
      CallStatus.timeout,
    },
    CallStatus.ringing: {
      CallStatus.accepted,
      CallStatus.rejected,
      CallStatus.timeout,
      CallStatus.cancelled,
      CallStatus.failed,
    },
    CallStatus.accepted: {
      CallStatus.connecting,
      CallStatus.connected,
      CallStatus.failed,
      CallStatus.cancelled,
    },
    CallStatus.connecting: {
      CallStatus.connected,
      CallStatus.failed,
      CallStatus.cancelled,
    },
    CallStatus.connected: {CallStatus.ended, CallStatus.failed},
    CallStatus.ended: {},
    CallStatus.rejected: {},
    CallStatus.cancelled: {},
    CallStatus.timeout: {},
    CallStatus.failed: {},
  };

  static bool canTransition(CallStatus from, CallStatus to) {
    return allowed[from]?.contains(to) ?? false;
  }
}
