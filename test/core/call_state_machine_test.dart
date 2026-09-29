import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/core/calling/call_state_machine.dart';
import 'package:gmatez_app/core/calling/call_status.dart';

void main() {
  test('allows ringing to accepted', () {
    expect(
      CallStateMachine.canTransition(CallStatus.ringing, CallStatus.accepted),
      isTrue,
    );
  });

  test('rejects ended to connected', () {
    expect(
      CallStateMachine.canTransition(CallStatus.ended, CallStatus.connected),
      isFalse,
    );
  });

  test('terminal states have no outbound transitions', () {
    for (final status in [
      CallStatus.ended,
      CallStatus.rejected,
      CallStatus.cancelled,
      CallStatus.timeout,
      CallStatus.failed,
    ]) {
      expect(CallStateMachine.allowed[status], isEmpty);
      expect(status.isTerminal, isTrue);
    }
  });
}
