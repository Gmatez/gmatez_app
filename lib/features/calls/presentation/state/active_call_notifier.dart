import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/config/app_environment.dart';
import '../../../../core/calling/call_media_provider.dart';
import '../../../../core/calling/call_permissions.dart';
import '../../../../core/calling/call_state_machine.dart';
import '../../../../core/calling/call_status.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../data/repositories/call_repository_impl.dart';
import '../../domain/entities/call_session.dart';
import '../../domain/repositories/call_repository.dart';

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepositoryImpl(ref.watch(apiClientProvider));
});

/// Selects call media from [AppConfig]. Production/staging never get mock.
final callMediaProvider = Provider<CallMediaProvider>((ref) {
  final config = ref.watch(appConfigProvider);
  switch (config.callingMediaProvider) {
    case CallingMediaProviderKind.mock:
      if (!config.allowsMockCallMedia) {
        throw StateError(
          'MockCallMediaProvider forbidden for ${config.environment.name}',
        );
      }
      return MockCallMediaProvider();
    case CallingMediaProviderKind.agora:
      return AgoraCallMediaProvider();
  }
});

class ActiveCallState {
  const ActiveCallState({
    this.incoming,
    this.active,
    this.busy = false,
    this.muted = false,
    this.cameraEnabled = true,
    this.speakerOn = true,
    this.mediaState = CallMediaConnectionState.idle,
    this.permissionMessage,
  });

  final CallSession? incoming;
  final CallSession? active;
  final bool busy;
  final bool muted;
  final bool cameraEnabled;
  final bool speakerOn;
  final CallMediaConnectionState mediaState;
  final String? permissionMessage;

  ActiveCallState copyWith({
    CallSession? incoming,
    CallSession? active,
    bool? busy,
    bool? muted,
    bool? cameraEnabled,
    bool? speakerOn,
    CallMediaConnectionState? mediaState,
    String? permissionMessage,
    bool clearIncoming = false,
    bool clearActive = false,
    bool clearPermission = false,
  }) {
    return ActiveCallState(
      incoming: clearIncoming ? null : incoming ?? this.incoming,
      active: clearActive ? null : active ?? this.active,
      busy: busy ?? this.busy,
      muted: muted ?? this.muted,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      speakerOn: speakerOn ?? this.speakerOn,
      mediaState: mediaState ?? this.mediaState,
      permissionMessage: clearPermission
          ? null
          : permissionMessage ?? this.permissionMessage,
    );
  }
}

class ActiveCallNotifier extends Notifier<ActiveCallState> {
  StreamSubscription<RealtimeEvent>? _sub;
  StreamSubscription<CallMediaConnectionState>? _mediaSub;
  Timer? _heartbeat;
  Timer? _tokenRenewal;
  bool _joiningMedia = false;
  bool _ending = false;
  final _permissions = const CallPermissions();

  CallRepository get _calls => ref.read(callRepositoryProvider);
  CallMediaProvider get _media => ref.read(callMediaProvider);
  RealtimeService get _realtime => ref.read(realtimeServiceProvider);

  String? get _myId => ref.read(authNotifierProvider).user?.id;

  @override
  ActiveCallState build() {
    _sub = _realtime.events.listen(_onEvent);
    _mediaSub = _media.connectionStates.listen((s) {
      state = state.copyWith(mediaState: s);
      if (s == CallMediaConnectionState.failed && state.active != null) {
        unawaited(_failRtc('media_failed'));
      }
    });
    ref.onDispose(() {
      _sub?.cancel();
      _mediaSub?.cancel();
      _heartbeat?.cancel();
      _tokenRenewal?.cancel();
    });
    return const ActiveCallState();
  }

  /// Restore non-terminal call after app resume / process restart.
  Future<void> restoreIfNeeded() async {
    if (state.active != null || state.incoming != null) {
      return;
    }
    final history = await _calls.history();
    if (history case Success(:final value)) {
      final me = _myId;
      if (me == null) {
        return;
      }
      for (final call in value.items) {
        if (!call.status.isTerminal &&
            (call.callerId == me || call.calleeId == me)) {
          state = state.copyWith(active: call);
          if (call.status == CallStatus.accepted ||
              call.status == CallStatus.connecting ||
              call.status == CallStatus.connected) {
            await _ensureRtcJoined(call);
          }
          return;
        }
      }
    }
  }

  Future<Result<CallSession>> startCall({
    required String calleeId,
    required String callType,
  }) async {
    if (state.active != null && !state.active!.status.isTerminal) {
      return const Failure(
        AppFailure(
          kind: FailureKind.callConflict,
          message: 'A call is already active',
          code: 'CALL_ALREADY_ACTIVE',
        ),
      );
    }
    state = state.copyWith(busy: true, clearPermission: true);
    final result = await _calls.create(
      calleeId: calleeId,
      callType: callType,
      idempotencyKey: const Uuid().v4(),
    );
    state = state.copyWith(busy: false);
    if (result case Success(:final value)) {
      state = state.copyWith(active: value, clearIncoming: true);
    }
    return result;
  }

  Future<Result<CallSession>> acceptIncoming() async {
    final incoming = state.incoming;
    if (incoming == null) {
      return const Failure(
        AppFailure(
          kind: FailureKind.notFound,
          message: 'No incoming call',
          code: 'NOT_FOUND',
        ),
      );
    }
    final permitted = await _ensurePermissions(video: incoming.isVideo);
    if (!permitted) {
      return Failure(
        AppFailure(
          kind: FailureKind.forbidden,
          message: state.permissionMessage ?? 'Microphone permission required',
          code: 'CALL_PERMISSION_DENIED',
        ),
      );
    }
    state = state.copyWith(busy: true);
    final result = await _calls.accept(incoming.id);
    state = state.copyWith(busy: false, clearIncoming: true);
    if (result case Success(:final value)) {
      state = state.copyWith(active: value);
      await _ensureRtcJoined(value, prefer: value.rtc);
      _startHeartbeat(value.id);
    }
    return result;
  }

  Future<void> rejectIncoming() async {
    final incoming = state.incoming;
    if (incoming == null) {
      return;
    }
    await _calls.reject(incoming.id);
    state = state.copyWith(clearIncoming: true);
  }

  Future<void> hangUp() async {
    if (_ending) {
      return;
    }
    _ending = true;
    try {
      final active = state.active;
      if (active == null) {
        return;
      }
      if (active.status == CallStatus.ringing ||
          active.status == CallStatus.initiated) {
        if (active.callerId == _myId) {
          await _calls.cancel(active.id);
        } else {
          await _calls.reject(active.id);
        }
      } else if (!active.status.isTerminal) {
        await _calls.end(active.id);
      }
      await _leave();
    } finally {
      _ending = false;
    }
  }

  Future<void> toggleMute() async {
    final next = !state.muted;
    await _media.setMuted(next);
    state = state.copyWith(muted: next);
  }

  Future<void> toggleCamera() async {
    final next = !state.cameraEnabled;
    await _media.setCameraEnabled(next);
    state = state.copyWith(cameraEnabled: next);
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speakerOn;
    await _media.setSpeakerEnabled(next);
    state = state.copyWith(speakerOn: next);
  }

  Future<void> switchCamera() async {
    await _media.switchCamera();
  }

  void _onEvent(RealtimeEvent event) {
    if (!event.name.startsWith('call.')) {
      return;
    }
    final next = CallSession.fromJson(event.payload);
    if (next.id.isEmpty) {
      return;
    }
    final me = _myId;
    if (me == null) {
      return;
    }
    if (next.callerId != me && next.calleeId != me) {
      return;
    }

    if (event.name == 'call.ringing' &&
        next.calleeId == me &&
        state.active == null) {
      state = state.copyWith(incoming: next);
      return;
    }

    final current = state.active;
    if (current == null || current.id != next.id) {
      if (next.status.isTerminal) {
        if (state.incoming?.id == next.id) {
          state = state.copyWith(clearIncoming: true);
        }
        return;
      }
      return;
    }

    if (current.status == next.status) {
      state = state.copyWith(
        active: current.copyWith(
          billedSeconds: next.billedSeconds,
          billedAmountCents: next.billedAmountCents,
          connectedAt: next.connectedAt,
          endedAt: next.endedAt,
          endReason: next.endReason,
        ),
      );
      return;
    }
    if (!CallStateMachine.canTransition(current.status, next.status) &&
        !next.status.isTerminal) {
      return;
    }
    final merged = current.copyWith(
      status: next.status,
      billedSeconds: next.billedSeconds,
      billedAmountCents: next.billedAmountCents,
      connectedAt: next.connectedAt,
      endedAt: next.endedAt,
      endReason: next.endReason,
    );
    if (merged.status.isTerminal) {
      unawaited(_leave());
      return;
    }
    if (merged.status == CallStatus.accepted ||
        merged.status == CallStatus.connecting ||
        merged.status == CallStatus.connected) {
      unawaited(_ensureRtcJoined(merged));
      _startHeartbeat(merged.id);
    }
    state = state.copyWith(active: merged);
  }

  Future<bool> _ensurePermissions({required bool video}) async {
    final result = await _permissions.ensureForCall(video: video);
    switch (result) {
      case CallPermissionResult.granted:
        state = state.copyWith(clearPermission: true);
        return true;
      case CallPermissionResult.denied:
        state = state.copyWith(
          permissionMessage: video
              ? 'Microphone and camera permission are required for video calls.'
              : 'Microphone permission is required for voice calls.',
        );
        return false;
      case CallPermissionResult.permanentlyDenied:
        state = state.copyWith(
          permissionMessage:
              'Permissions permanently denied. Open system settings to enable microphone${video ? ' and camera' : ''}.',
        );
        return false;
      case CallPermissionResult.restricted:
        state = state.copyWith(
          permissionMessage: 'Calling permissions are restricted on this device.',
        );
        return false;
    }
  }

  Future<void> _ensureRtcJoined(
    CallSession call, {
    CallRtcCredentials? prefer,
  }) async {
    if (_joiningMedia || call.status.isTerminal) {
      return;
    }
    if (call.status == CallStatus.ringing ||
        call.status == CallStatus.initiated) {
      return;
    }

    final permitted = await _ensurePermissions(video: call.isVideo);
    if (!permitted) {
      await _failRtc('permission_denied');
      return;
    }

    _joiningMedia = true;
    try {
      CallRtcCredentials? creds = prefer ?? call.rtc;
      if (creds == null || creds.token.isEmpty) {
        final tokenResult = await _calls.rtcToken(call.id);
        if (tokenResult case Success(:final value)) {
          creds = value;
        } else if (tokenResult case Failure(:final failure)) {
          await _failRtc(failure.code ?? 'rtc_token_failed');
          return;
        }
      }
      if (creds == null || creds.token.isEmpty) {
        await _failRtc('rtc_token_missing');
        return;
      }

      await _media.join(
        appId: creds.appId,
        channelName: creds.channelName,
        token: creds.token,
        uid: creds.uid,
        video: call.isVideo,
      );
      state = state.copyWith(
        active: call.copyWith(rtc: creds),
        cameraEnabled: call.isVideo,
      );
      _scheduleTokenRenewal(call.id, creds.tokenExpiresAt);

      if (!call.isMockProvider) {
        final joined = await _calls.rtcJoined(call.id);
        if (joined case Success(:final value)) {
          state = state.copyWith(active: value.copyWith(rtc: creds));
        }
      }
    } catch (_) {
      await _failRtc('join_failed');
    } finally {
      _joiningMedia = false;
    }
  }

  void _scheduleTokenRenewal(String callId, DateTime? expiresAt) {
    _tokenRenewal?.cancel();
    if (expiresAt == null) {
      return;
    }
    final renewAt = expiresAt.subtract(const Duration(minutes: 5));
    final delay = renewAt.difference(DateTime.now());
    if (delay.isNegative) {
      unawaited(_renewToken(callId));
      return;
    }
    _tokenRenewal = Timer(delay, () => unawaited(_renewToken(callId)));
  }

  Future<void> _renewToken(String callId) async {
    final active = state.active;
    if (active == null || active.id != callId || active.status.isTerminal) {
      return;
    }
    final result = await _calls.rtcToken(callId);
    if (result case Success(:final value)) {
      await _media.renewToken(value.token);
      state = state.copyWith(active: active.copyWith(rtc: value));
      _scheduleTokenRenewal(callId, value.tokenExpiresAt);
    }
  }

  Future<void> _failRtc(String reason) async {
    final active = state.active;
    if (active == null || active.status.isTerminal) {
      return;
    }
    await _calls.rtcFailed(active.id, reason: reason);
    await _leave();
  }

  void _startHeartbeat(String callId) {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
      _realtime.emit('call.heartbeat', {'callId': callId});
      unawaited(_calls.heartbeat(callId));
    });
  }

  Future<void> _leave() async {
    _heartbeat?.cancel();
    _tokenRenewal?.cancel();
    await _media.leave();
    state = state.copyWith(
      clearActive: true,
      clearIncoming: true,
      muted: false,
      cameraEnabled: true,
      speakerOn: true,
      mediaState: CallMediaConnectionState.idle,
      clearPermission: true,
    );
  }
}

final activeCallProvider =
    NotifierProvider<ActiveCallNotifier, ActiveCallState>(
      ActiveCallNotifier.new,
    );
