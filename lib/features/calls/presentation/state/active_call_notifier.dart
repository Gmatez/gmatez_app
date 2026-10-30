import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/config/app_environment.dart';
import '../../../../core/calling/call_media_provider.dart';
import '../../../../core/calling/call_permissions.dart';
import '../../../../core/calling/call_state_machine.dart';
import '../../../../core/calling/call_status.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/push/push_notifications.dart';
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
    this.callScreenHidden = false,
    this.peerConnectionIssue = false,
  });

  final CallSession? incoming;
  final CallSession? active;
  final bool busy;
  final bool muted;
  final bool cameraEnabled;
  final bool speakerOn;
  final CallMediaConnectionState mediaState;
  final String? permissionMessage;
  final bool callScreenHidden;

  /// True while the peer's realtime socket is known to be disconnected
  /// (via `call.peer-disconnected`) and hasn't reconnected yet. Purely a UX
  /// signal — never affects billing/timeout, which stay governed by the
  /// server's heartbeat/extend-hold jobs regardless.
  final bool peerConnectionIssue;

  ActiveCallState copyWith({
    CallSession? incoming,
    CallSession? active,
    bool? busy,
    bool? muted,
    bool? cameraEnabled,
    bool? speakerOn,
    CallMediaConnectionState? mediaState,
    String? permissionMessage,
    bool? callScreenHidden,
    bool? peerConnectionIssue,
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
      callScreenHidden: callScreenHidden ?? this.callScreenHidden,
      peerConnectionIssue: clearActive
          ? false
          : peerConnectionIssue ?? this.peerConnectionIssue,
    );
  }
}

class ActiveCallNotifier extends Notifier<ActiveCallState> {
  StreamSubscription<RealtimeEvent>? _sub;
  StreamSubscription<CallMediaConnectionState>? _mediaSub;
  StreamSubscription<String>? _pushSub;
  StreamSubscription<RealtimeConnectionState>? _connectionSub;
  Timer? _heartbeat;
  Timer? _tokenRenewal;
  bool _joiningMedia = false;
  bool _ending = false;
  bool _wasDisconnected = false;
  int _heartbeatFailures = 0;
  final _permissions = const CallPermissions();

  CallRepository get _calls => ref.read(callRepositoryProvider);
  CallMediaProvider get _media => ref.read(callMediaProvider);
  RealtimeService get _realtime => ref.read(realtimeServiceProvider);

  String? get _myId => ref.read(authNotifierProvider).user?.id;

  @override
  ActiveCallState build() {
    _sub = _realtime.events.listen(_onEvent);
    _connectionSub = _realtime.connection.listen((connectionState) {
      if (connectionState == RealtimeConnectionState.disconnected ||
          connectionState == RealtimeConnectionState.reconnecting) {
        _wasDisconnected = true;
        return;
      }
      if (connectionState == RealtimeConnectionState.connected &&
          _wasDisconnected) {
        _wasDisconnected = false;
        unawaited(resyncIfActive());
      }
    });
    _pushSub = ref.read(incomingPushBusProvider).calls.listen((callId) {
      unawaited(openIncomingFromPush(callId));
    });
    final pending = ref.read(incomingPushBusProvider).pendingCallId;
    if (pending != null) {
      unawaited(openIncomingFromPush(pending));
    }
    _mediaSub = _media.connectionStates.listen((s) {
      state = state.copyWith(mediaState: s);
      if (s == CallMediaConnectionState.failed && state.active != null) {
        unawaited(_failRtc('media_failed'));
      }
    });
    // Captured now, not read lazily inside onDispose below — Riverpod
    // disallows ref.read()/ref.watch() from within a dispose callback.
    final media = _media;
    ref.onDispose(() {
      _sub?.cancel();
      _connectionSub?.cancel();
      _mediaSub?.cancel();
      _pushSub?.cancel();
      _heartbeat?.cancel();
      _tokenRenewal?.cancel();
      // Best-effort: if this provider is ever torn down mid-call, don't
      // leak the native Agora engine/mic/camera.
      unawaited(media.leave().catchError((_) {}));
    });
    return const ActiveCallState();
  }

  /// Open a ringing call that arrived by push while the app was backgrounded.
  Future<void> openIncomingFromPush(String callId) async {
    if (callId.isEmpty) {
      return;
    }
    if (state.incoming?.id == callId || state.active?.id == callId) {
      ref.read(incomingPushBusProvider).clear(callId);
      return;
    }
    final result = await _calls.getById(callId);
    if (result case Success(:final value)) {
      final me = _myId;
      if (me == null || (value.callerId != me && value.calleeId != me)) {
        return;
      }
      if (value.status.isTerminal) {
        ref.read(incomingPushBusProvider).clear(callId);
        unawaited(cancelIncomingCallNotification(callId));
        return;
      }
      if (value.calleeId == me &&
          (value.status == CallStatus.ringing ||
              value.status == CallStatus.initiated)) {
        state = state.copyWith(incoming: value);
      } else {
        state = state.copyWith(active: value, callScreenHidden: false);
        unawaited(cancelIncomingCallNotification(callId));
      }
      ref.read(incomingPushBusProvider).clear(callId);
    }
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
          state = state.copyWith(active: call, callScreenHidden: false);
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
      final staleIncomingId = state.incoming?.id;
      state = state.copyWith(
        active: value,
        clearIncoming: true,
        callScreenHidden: false,
      );
      if (staleIncomingId != null) {
        unawaited(cancelIncomingCallNotification(staleIncomingId));
      }
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
      final message =
          state.permissionMessage ?? 'Microphone permission required';
      // Tell the backend the callee effectively declined (don't make the
      // caller wait out the full ring timeout), and dismiss the overlay —
      // otherwise this just looked like Accept silently did nothing.
      unawaited(_calls.reject(incoming.id));
      state = state.copyWith(clearIncoming: true, clearPermission: true);
      unawaited(cancelIncomingCallNotification(incoming.id));
      return Failure(
        AppFailure(
          kind: FailureKind.forbidden,
          message: message,
          code: 'CALL_PERMISSION_DENIED',
        ),
      );
    }
    state = state.copyWith(busy: true);
    final result = await _calls.accept(incoming.id);
    state = state.copyWith(busy: false, clearIncoming: true);
    unawaited(cancelIncomingCallNotification(incoming.id));
    if (result case Success(:final value)) {
      state = state.copyWith(active: value, callScreenHidden: false);
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
    unawaited(cancelIncomingCallNotification(incoming.id));
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

  void showCallScreen() {
    state = state.copyWith(callScreenHidden: false);
  }

  void hideCallScreen() {
    state = state.copyWith(callScreenHidden: true);
  }

  Future<void> toggleMute() async {
    final next = !state.muted;
    try {
      await _media.setMuted(next);
      state = state.copyWith(muted: next);
    } catch (_) {
      // Leave state.muted unchanged — a transient platform-channel error
      // must not make the button claim a state that never actually took.
    }
  }

  Future<void> toggleCamera() async {
    final next = !state.cameraEnabled;
    try {
      await _media.setCameraEnabled(next);
      state = state.copyWith(cameraEnabled: next);
    } catch (_) {
      // Leave state.cameraEnabled unchanged — see toggleMute().
    }
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speakerOn;
    try {
      await _media.setSpeakerEnabled(next);
      state = state.copyWith(speakerOn: next);
    } catch (_) {
      // Leave state.speakerOn unchanged — see toggleMute().
    }
  }

  Future<void> switchCamera() async {
    try {
      await _media.switchCamera();
    } catch (_) {
      // Best-effort; nothing in state tracks which physical camera is active.
    }
  }

  void _onEvent(RealtimeEvent event) {
    if (!event.name.startsWith('call.')) {
      return;
    }
    // These carry {callId, userId}, not a full call payload — handle before
    // the generic CallSession.fromJson parse below.
    if (event.name == 'call.peer-disconnected' ||
        event.name == 'call.peer-reconnected') {
      final callId = event.payload['callId'] as String?;
      if (callId != null && state.active?.id == callId) {
        state = state.copyWith(
          peerConnectionIssue: event.name == 'call.peer-disconnected',
        );
      }
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
      // No matching state.active for this event — it can only be about our
      // state.incoming. Dismiss the ringing overlay whenever the call has
      // moved past ringing for ANY reason (terminal, or progressed to
      // accepted/connecting/connected because it was answered on another
      // signed-in session) — this device never became the active one, so
      // there's nothing left for it to do with this call.
      if (state.incoming?.id == next.id &&
          next.status != CallStatus.ringing &&
          next.status != CallStatus.initiated) {
        state = state.copyWith(clearIncoming: true);
        unawaited(cancelIncomingCallNotification(next.id));
      }
      return;
    }
    _applyServerCall(next);
  }

  /// Reconciles `state.active` against a fresh server-reported [next],
  /// shared by the live socket-event path and the reconnect/resume resync
  /// paths below. Caller must already know `next` is about `state.active`.
  void _applyServerCall(CallSession next) {
    final current = state.active;
    if (current == null || current.id != next.id) {
      return;
    }
    if (current.status == next.status) {
      final updated = current.copyWith(
        billedSeconds: next.billedSeconds,
        billedAmountCents: next.billedAmountCents,
        connectedAt: next.connectedAt,
        endedAt: next.endedAt,
        endReason: next.endReason,
      );
      state = state.copyWith(active: updated);
      if (_needsMediaJoin(updated)) {
        unawaited(_ensureRtcJoined(updated));
      }
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
    state = state.copyWith(active: merged, peerConnectionIssue: false);
  }

  /// Re-fetches state.active/incoming from the server and reconciles.
  /// Used on realtime reconnect and app resume — anywhere the client's
  /// in-memory call state may have silently drifted from the server's.
  Future<void> resyncIfActive() async {
    final activeId = state.active?.id;
    if (activeId != null) {
      final result = await _calls.getById(activeId);
      if (result case Success(:final value)) {
        _applyServerCall(value);
      }
      return;
    }
    final incomingId = state.incoming?.id;
    if (incomingId != null) {
      final result = await _calls.getById(incomingId);
      if (result case Success(:final value)) {
        if (value.status.isTerminal ||
            (value.status != CallStatus.ringing &&
                value.status != CallStatus.initiated)) {
          state = state.copyWith(clearIncoming: true);
          unawaited(cancelIncomingCallNotification(incomingId));
        }
      }
    }
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
          permissionMessage:
              'Calling permissions are restricted on this device.',
        );
        return false;
    }
  }

  bool _needsMediaJoin(CallSession call) {
    if (call.status.isTerminal ||
        call.status == CallStatus.ringing ||
        call.status == CallStatus.initiated) {
      return false;
    }
    return state.mediaState != CallMediaConnectionState.connected ||
        call.status != CallStatus.connected;
  }

  bool _usableRtc(CallRtcCredentials? creds) {
    if (creds == null) {
      return false;
    }
    return creds.appId.isNotEmpty &&
        creds.channelName.isNotEmpty &&
        creds.token.isNotEmpty &&
        creds.uid > 0;
  }

  /// Caller always mints a token from `/rtc-token`.
  /// Callee uses `rtc` from accept when it already has a real token.
  Future<CallRtcCredentials?> _resolveRtcCredentials(
    CallSession call, {
    CallRtcCredentials? prefer,
  }) async {
    final isCaller = _myId != null && _myId == call.callerId;
    if (!isCaller && _usableRtc(prefer)) {
      return prefer;
    }
    final tokenResult = await _calls.rtcToken(call.id);
    if (tokenResult case Success(:final value)) {
      if (_usableRtc(value)) {
        return value;
      }
      await _failRtc('rtc_token_missing');
      return null;
    } else if (tokenResult case Failure(:final failure)) {
      await _failRtc(failure.code ?? 'rtc_token_failed');
      return null;
    }
    return null;
  }

  Future<void> _ensureRtcJoined(
    CallSession call, {
    CallRtcCredentials? prefer,
  }) async {
    if (_joiningMedia || !_needsMediaJoin(call)) {
      return;
    }

    _joiningMedia = true;
    try {
      if (!call.isMockProvider && _media.name != 'agora') {
        await _failRtc('agora_media_required');
        return;
      }
      final permitted = await _ensurePermissions(video: call.isVideo);
      if (!permitted) {
        await _failRtc('permission_denied');
        return;
      }

      final creds = await _resolveRtcCredentials(call, prefer: prefer);
      if (creds == null) {
        return;
      }

      await _media.join(
        appId: creds.appId,
        channelName: creds.channelName,
        token: creds.token,
        uid: creds.uid,
        video: call.isVideo,
      );
      final current = state.active;
      if (current == null ||
          current.id != call.id ||
          current.status.isTerminal) {
        await _media.leave();
        return;
      }
      state = state.copyWith(
        active: current.copyWith(rtc: creds),
        cameraEnabled: call.isVideo,
      );
      _scheduleTokenRenewal(call.id, creds.tokenExpiresAt);

      if (!call.isMockProvider) {
        final joined = await _calls.rtcJoined(call.id);
        if (joined case Success(:final value)) {
          state = state.copyWith(active: value.copyWith(rtc: creds));
        } else if (joined case Failure(:final failure)) {
          await _failRtc(failure.code ?? 'rtc_joined_failed');
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
    } else {
      // Transient failure (network blip, momentary server error) — retry
      // shortly rather than silently giving up and letting the token
      // expire mid-call. _scheduleTokenRenewal cancels any prior timer.
      _tokenRenewal?.cancel();
      _tokenRenewal = Timer(
        const Duration(seconds: 30),
        () => unawaited(_renewToken(callId)),
      );
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
    _heartbeatFailures = 0;
    _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
      _realtime.emit('call.heartbeat', {'callId': callId});
      unawaited(
        _calls.heartbeat(callId).then((result) {
          if (result case Failure()) {
            _heartbeatFailures += 1;
            // A couple of REST heartbeat failures in a row means our view
            // of the call may be stale (expired session, dropped network)
            // — resync rather than free-running with no signal at all.
            if (_heartbeatFailures >= 2) {
              _heartbeatFailures = 0;
              unawaited(resyncIfActive());
            }
          } else {
            _heartbeatFailures = 0;
          }
        }),
      );
    });
  }

  Future<void> _leave() async {
    _heartbeat?.cancel();
    _tokenRenewal?.cancel();
    final staleIncomingId = state.incoming?.id;
    final staleActiveId = state.active?.id;
    await _media.leave();
    state = state.copyWith(
      clearActive: true,
      clearIncoming: true,
      muted: false,
      cameraEnabled: true,
      speakerOn: true,
      mediaState: CallMediaConnectionState.idle,
      callScreenHidden: false,
      clearPermission: true,
    );
    if (staleIncomingId != null) {
      unawaited(cancelIncomingCallNotification(staleIncomingId));
    }
    if (staleActiveId != null) {
      unawaited(cancelIncomingCallNotification(staleActiveId));
    }
  }
}

final activeCallProvider =
    NotifierProvider<ActiveCallNotifier, ActiveCallState>(
      ActiveCallNotifier.new,
    );
