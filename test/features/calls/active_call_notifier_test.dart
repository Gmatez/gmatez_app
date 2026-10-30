import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/core/calling/call_media_provider.dart';
import 'package:gmatez_app/core/calling/call_status.dart';
import 'package:gmatez_app/core/di/core_providers.dart';
import 'package:gmatez_app/core/utils/result.dart';
import 'package:gmatez_app/features/auth/domain/entities/session.dart';
import 'package:gmatez_app/features/auth/presentation/state/auth_notifier.dart';
import 'package:gmatez_app/features/auth/presentation/state/auth_state.dart';
import 'package:gmatez_app/features/calls/domain/entities/call_session.dart';
import 'package:gmatez_app/features/calls/presentation/state/active_call_notifier.dart';

import '../../fakes/fake_calling.dart';

const _me = 'user-me';
const _caller = 'user-caller';

/// Returns AuthState.authenticated(_me) synchronously, bypassing the real
/// session-restore flow entirely.
class _FixedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState.authenticated(
      AuthUser(
        id: _me,
        email: 'me@example.com',
        role: 'USER',
        status: 'ACTIVE',
      ),
    );
  }
}

ProviderContainer _buildContainer(
  FakeRealtimeService realtime, {
  FakeCallRepository? repository,
}) {
  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(_FixedAuthNotifier.new),
      callRepositoryProvider.overrideWithValue(
        repository ?? FakeCallRepository(),
      ),
      callMediaProvider.overrideWithValue(MockCallMediaProvider()),
      realtimeServiceProvider.overrideWithValue(realtime),
    ],
  );
  addTearDown(container.dispose);
  // Force build() to run now so the realtime.events subscription exists
  // before any test pushes an event — otherwise an event pushed before
  // the provider is first read would be silently dropped.
  container.read(activeCallProvider);
  return container;
}

void main() {
  group('ActiveCallNotifier — stale incoming overlay (F2)', () {
    test(
      'dismisses state.incoming when the call progresses past ringing without this device becoming active',
      () async {
        final realtime = FakeRealtimeService();
        final container = _buildContainer(realtime);
        final notifier = container.read(activeCallProvider.notifier);

        // Simulate the incoming-ring event (callee == me, no active call yet).
        realtime.push('call.ringing', {
          'id': 'call-1',
          'callerId': _caller,
          'calleeId': _me,
          'status': 'RINGING',
          'callType': 'VOICE',
          'provider': 'mock',
          'ratePerMinuteCents': 100,
        });
        await Future<void>.delayed(Duration.zero);
        expect(container.read(activeCallProvider).incoming?.id, 'call-1');

        // The call was answered elsewhere: this device never became
        // active, but the call progressed past ringing.
        realtime.push('call.accepted', {
          'id': 'call-1',
          'callerId': _caller,
          'calleeId': _me,
          'status': 'ACCEPTED',
          'callType': 'VOICE',
          'provider': 'mock',
          'ratePerMinuteCents': 100,
        });
        await Future<void>.delayed(Duration.zero);

        expect(container.read(activeCallProvider).incoming, isNull);
        addTearDown(notifier.hangUp);
      },
    );

    test('keeps state.incoming while the call is still ringing', () async {
      final realtime = FakeRealtimeService();
      final container = _buildContainer(realtime);

      realtime.push('call.ringing', {
        'id': 'call-2',
        'callerId': _caller,
        'calleeId': _me,
        'status': 'RINGING',
        'callType': 'VOICE',
        'provider': 'mock',
        'ratePerMinuteCents': 100,
      });
      await Future<void>.delayed(Duration.zero);

      // A duplicate/retried ringing event for the same call must not
      // clear the overlay.
      realtime.push('call.ringing', {
        'id': 'call-2',
        'callerId': _caller,
        'calleeId': _me,
        'status': 'RINGING',
        'callType': 'VOICE',
        'provider': 'mock',
        'ratePerMinuteCents': 100,
      });
      await Future<void>.delayed(Duration.zero);

      expect(container.read(activeCallProvider).incoming?.id, 'call-2');
    });
  });

  group('ActiveCallNotifier — startCall guard (F1)', () {
    test(
      'a second startCall while one is active is rejected without a second repository call',
      () async {
        final realtime = FakeRealtimeService();
        final repository = FakeCallRepository()
          ..createResult = Success(
            CallSession(
              id: 'call-5',
              callerId: _me,
              calleeId: 'user-callee',
              callType: 'VOICE',
              status: CallStatus.ringing,
              provider: 'mock',
              ratePerMinuteCents: 100,
            ),
          );
        final container = _buildContainer(realtime, repository: repository);
        final notifier = container.read(activeCallProvider.notifier);

        final first = await notifier.startCall(
          calleeId: 'user-callee',
          callType: 'VOICE',
        );
        expect(first.isSuccess, isTrue);
        expect(repository.createCalls, 1);

        // This is exactly the scenario a double-tap on a call button
        // produces: startCall() invoked again while state.active already
        // holds a non-terminal call.
        final second = await notifier.startCall(
          calleeId: 'someone-else',
          callType: 'VOICE',
        );
        switch (second) {
          case Failure(:final failure):
            expect(failure.code, 'CALL_ALREADY_ACTIVE');
          case Success():
            fail('expected the second startCall to reject while one is active');
        }
        // The guard must short-circuit before touching the repository again.
        expect(repository.createCalls, 1);
      },
    );
  });

  group('rtcFailed request body (F6)', () {
    // Mirrors call_repository_impl.dart's `body: {'reason': ?reason}`.
    // The old `{?reason}` was a null-aware Set element (no key), which
    // jsonEncode cannot handle at all — this guards against that
    // regression by exercising the exact same literal shape.
    Map<String, dynamic> buildBody(String? reason) => {'reason': ?reason};

    test('encodes {reason: ...} as JSON, not a malformed Set literal', () {
      final body = buildBody('media_failed');
      expect(body, {'reason': 'media_failed'});
      expect(jsonEncode(body), '{"reason":"media_failed"}');
    });

    test('omits the key entirely when reason is null (still valid JSON)', () {
      final body = buildBody(null);
      expect(body, isEmpty);
      expect(jsonEncode(body), '{}');
    });
  });
}
