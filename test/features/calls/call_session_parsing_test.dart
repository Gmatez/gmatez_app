import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/core/calling/call_status.dart';
import 'package:gmatez_app/features/calls/domain/entities/call_session.dart';

void main() {
  test('parses call payloads with missing optional fields', () {
    final call = CallSession.fromJson({
      'callId': 'c1',
      'callerId': 'a',
      'calleeId': 'b',
      'status': 'RINGING',
    });
    expect(call.id, 'c1');
    expect(call.status, CallStatus.ringing);
    expect(call.callType, 'VOICE');
    expect(call.billedAmountCents, 0);
  });

  test('parses caller display fields from signaling payloads', () {
    final call = CallSession.fromJson({
      'id': 'c2',
      'callerId': 'a',
      'calleeId': 'b',
      'status': 'RINGING',
      'callType': 'VIDEO',
      'callerDisplayName': 'Alice',
      'calleeDisplayName': 'Bob',
    });
    expect(call.isVideo, isTrue);
    expect(call.callerDisplayName, 'Alice');
    expect(call.calleeDisplayName, 'Bob');
  });

  test('parses rtc credentials from accept/token payloads', () {
    final call = CallSession.fromJson({
      'id': 'c3',
      'callerId': 'a',
      'calleeId': 'b',
      'status': 'CONNECTING',
      'provider': 'agora',
      'rtcChannelName': 'gmatez-call-c3',
      'rtc': {
        'appId': 'app',
        'channelName': 'gmatez-call-c3',
        'uid': 2,
        'token': 'tok',
        'tokenExpiresAt': '2026-09-18T12:00:00.000Z',
      },
    });
    expect(call.rtc?.uid, 2);
    expect(call.rtc?.channelName, 'gmatez-call-c3');
    expect(call.isMockProvider, isFalse);
  });
}
