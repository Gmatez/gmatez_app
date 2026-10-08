import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/widgets.dart';

import 'call_audio_session.dart';

/// Isolates RTC from call business logic.
///
/// - [MockCallMediaProvider]: signaling+billing real; media simulated (local/test only).
/// - [AgoraCallMediaProvider]: production Agora RTC path.
abstract class CallMediaProvider {
  String get name;

  /// Connection/media state for UI (reconnecting, failed, etc.).
  Stream<CallMediaConnectionState> get connectionStates;

  int? get remoteUid;

  Future<void> join({
    required String appId,
    required String channelName,
    required String token,
    required int uid,
    required bool video,
  });

  Future<void> renewToken(String token);

  Future<void> leave();
  Future<void> setMuted(bool muted);
  Future<void> setCameraEnabled(bool enabled);
  Future<void> setSpeakerEnabled(bool enabled);
  Future<void> switchCamera();

  /// Fires when the local or remote video view becomes available.
  Listenable get videoLayout;

  Widget? buildLocalPreview();
  Widget? buildRemoteVideo();
}

enum CallMediaConnectionState {
  idle,
  connecting,
  connected,
  reconnecting,
  failed,
  disconnected,
}

class MockCallMediaProvider implements CallMediaProvider {
  @override
  String get name => 'mock';

  final _states = StreamController<CallMediaConnectionState>.broadcast();
  final _layout = ChangeNotifier();
  bool joined = false;
  bool muted = false;
  bool cameraEnabled = false;
  bool speakerEnabled = true;

  @override
  Stream<CallMediaConnectionState> get connectionStates => _states.stream;

  @override
  Listenable get videoLayout => _layout;

  @override
  int? get remoteUid => joined ? 2 : null;

  @override
  Future<void> join({
    required String appId,
    required String channelName,
    required String token,
    required int uid,
    required bool video,
  }) async {
    if (channelName.isEmpty || token.isEmpty) {
      throw StateError('Missing calling session credentials');
    }
    if (joined) {
      return;
    }
    _states.add(CallMediaConnectionState.connecting);
    joined = true;
    cameraEnabled = video;
    _states.add(CallMediaConnectionState.connected);
  }

  @override
  Future<void> renewToken(String token) async {}

  @override
  Future<void> leave() async {
    joined = false;
    muted = false;
    cameraEnabled = false;
    speakerEnabled = true;
    _states.add(CallMediaConnectionState.disconnected);
  }

  @override
  Future<void> setMuted(bool muted) async {
    this.muted = muted;
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    cameraEnabled = enabled;
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {
    speakerEnabled = enabled;
  }

  @override
  Future<void> switchCamera() async {}

  @override
  Widget? buildLocalPreview() => null;

  @override
  Widget? buildRemoteVideo() => null;
}

/// Production Agora RTC provider. Certificate never lives in the app —
/// tokens come from `POST /calls/:id/rtc-token`.
class AgoraCallMediaProvider implements CallMediaProvider {
  AgoraCallMediaProvider();

  @override
  String get name => 'agora';

  final _states = StreamController<CallMediaConnectionState>.broadcast();
  final _layout = _VideoLayoutTick();
  RtcEngine? _engine;
  bool _joining = false;
  bool _joined = false;
  int? _remoteUid;
  String? _appId;
  String? _channelName;
  bool _video = false;
  Completer<void>? _joinWait;
  VideoViewController? _localView;
  VideoViewController? _remoteView;
  int? _remoteViewUid;

  @override
  Stream<CallMediaConnectionState> get connectionStates => _states.stream;

  @override
  Listenable get videoLayout => _layout;

  @override
  int? get remoteUid => _remoteUid;

  @override
  Future<void> join({
    required String appId,
    required String channelName,
    required String token,
    required int uid,
    required bool video,
  }) async {
    if (_joined && _channelName == channelName && _appId == appId) {
      return;
    }
    if (_joining) {
      final pending = _joinWait;
      if (pending != null) {
        await pending.future;
      }
      return;
    }
    if (appId.isEmpty || channelName.isEmpty || token.isEmpty || uid <= 0) {
      throw StateError('Missing Agora RTC credentials from server');
    }
    _joining = true;
    _video = video;
    _appId = appId;
    _channelName = channelName;
    _joinWait = Completer<void>();
    _states.add(CallMediaConnectionState.connecting);

    try {
      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            _joined = true;
            _joining = false;
            _states.add(CallMediaConnectionState.connected);
            final wait = _joinWait;
            if (wait != null && !wait.isCompleted) {
              wait.complete();
            }
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            _bindRemote(remoteUid);
            _states.add(CallMediaConnectionState.connected);
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (_remoteUid == remoteUid) {
              _remoteUid = null;
              _remoteViewUid = null;
              final previous = _remoteView;
              _remoteView = null;
              unawaited(previous?.dispose());
              _layout.tick();
            }
          },
          onRemoteVideoStateChanged: (
            connection,
            remoteUid,
            state,
            reason,
            elapsed,
          ) {
            if (state == RemoteVideoState.remoteVideoStateStarting ||
                state == RemoteVideoState.remoteVideoStateDecoding) {
              _bindRemote(remoteUid);
            }
          },
          onConnectionStateChanged: (connection, state, reason) {
            switch (state) {
              case ConnectionStateType.connectionStateReconnecting:
                _states.add(CallMediaConnectionState.reconnecting);
              case ConnectionStateType.connectionStateConnected:
                _states.add(CallMediaConnectionState.connected);
              case ConnectionStateType.connectionStateFailed:
                _failJoin(StateError('Agora connection failed: $reason'));
              case ConnectionStateType.connectionStateDisconnected:
                if (_joined) {
                  _states.add(CallMediaConnectionState.reconnecting);
                } else {
                  _states.add(CallMediaConnectionState.disconnected);
                }
              default:
                break;
            }
          },
          onError: (err, msg) {
            if (!_joined && _fatalJoinError(err)) {
              _failJoin(StateError('Agora join failed: $err $msg'));
            }
          },
          onTokenPrivilegeWillExpire: (connection, token) {
            // ActiveCallNotifier renews via backend before expiry.
          },
        ),
      );

      await CallAudioSession.start();
      await engine.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );
      await engine.enableAudio();
      await engine.setDefaultAudioRouteToSpeakerphone(true);
      if (video) {
        await engine.enableVideo();
        _localView = VideoViewController(
          rtcEngine: engine,
          useAndroidSurfaceView: Platform.isAndroid,
          canvas: const VideoCanvas(
            uid: 0,
            renderMode: RenderModeType.renderModeHidden,
          ),
        );
        await engine.startPreview();
        _layout.tick();
      } else {
        await engine.disableVideo();
      }
      await engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: video,
          autoSubscribeAudio: true,
          autoSubscribeVideo: video,
        ),
      );
      await _joinWait!.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('Agora channel join timed out');
        },
      );
      _joinWait = null;
      try {
        await engine.setEnableSpeakerphone(true);
        await engine.muteAllRemoteAudioStreams(false);
        if (video) {
          await engine.muteAllRemoteVideoStreams(false);
          await engine.updateChannelMediaOptions(
            const ChannelMediaOptions(
              publishMicrophoneTrack: true,
              publishCameraTrack: true,
              autoSubscribeAudio: true,
              autoSubscribeVideo: true,
            ),
          );
        }
      } catch (_) {
        // Join already succeeded. A speaker-route failure must not drop media.
      }
    } catch (e) {
      _joining = false;
      _states.add(CallMediaConnectionState.failed);
      await leave();
      rethrow;
    }
  }

  void _bindRemote(int remoteUid) {
    final engine = _engine;
    final channel = _channelName;
    if (engine == null || channel == null || remoteUid <= 0) {
      return;
    }
    _remoteUid = remoteUid;
    if (_remoteView != null && _remoteViewUid == remoteUid) {
      _layout.tick();
      return;
    }
    final previous = _remoteView;
    _remoteViewUid = remoteUid;
    _remoteView = VideoViewController.remote(
      rtcEngine: engine,
      useAndroidSurfaceView: Platform.isAndroid,
      canvas: VideoCanvas(
        uid: remoteUid,
        renderMode: RenderModeType.renderModeHidden,
      ),
      connection: RtcConnection(channelId: channel),
    );
    if (previous != null) {
      unawaited(previous.dispose());
    }
    _layout.tick();
  }

  bool _fatalJoinError(ErrorCodeType err) {
    return err == ErrorCodeType.errInvalidToken ||
        err == ErrorCodeType.errInvalidAppId ||
        err == ErrorCodeType.errTokenExpired ||
        err == ErrorCodeType.errJoinChannelRejected ||
        err == ErrorCodeType.errInvalidChannelName ||
        err == ErrorCodeType.errNotInitialized ||
        err == ErrorCodeType.errNoPermission;
  }

  void _failJoin(Object error) {
    final wait = _joinWait;
    if (wait != null && !wait.isCompleted) {
      wait.completeError(error);
    }
    _states.add(CallMediaConnectionState.failed);
  }

  @override
  Future<void> renewToken(String token) async {
    final engine = _engine;
    if (engine == null || token.isEmpty) {
      return;
    }
    await engine.renewToken(token);
  }

  @override
  Future<void> leave() async {
    await CallAudioSession.stop();
    final engine = _engine;
    final wait = _joinWait;
    _engine = null;
    _joinWait = null;
    _joined = false;
    _joining = false;
    _remoteUid = null;
    _channelName = null;
    final localView = _localView;
    final remoteView = _remoteView;
    _localView = null;
    _remoteView = null;
    _remoteViewUid = null;
    unawaited(localView?.dispose());
    unawaited(remoteView?.dispose());
    _layout.tick();
    if (wait != null && !wait.isCompleted) {
      wait.future.ignore();
      wait.completeError(StateError('Left channel before Agora join finished'));
    }
    if (engine != null) {
      try {
        await engine.leaveChannel();
        await engine.release();
      } catch (_) {
        // Best-effort cleanup.
      }
    }
    _states.add(CallMediaConnectionState.disconnected);
  }

  @override
  Future<void> setMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    await _engine?.enableLocalVideo(enabled);
    await _engine?.muteLocalVideoStream(!enabled);
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {
    await _engine?.setEnableSpeakerphone(enabled);
  }

  @override
  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  @override
  Widget? buildLocalPreview() {
    final controller = _localView;
    if (controller == null || !_video) {
      return null;
    }
    return AgoraVideoView(
      key: const ValueKey('gmatez-local-video'),
      controller: controller,
    );
  }

  @override
  Widget? buildRemoteVideo() {
    final controller = _remoteView;
    final uid = _remoteViewUid;
    if (controller == null || uid == null || !_video) {
      return null;
    }
    return AgoraVideoView(
      key: ValueKey('gmatez-remote-video-$uid'),
      controller: controller,
    );
  }
}

class _VideoLayoutTick extends ChangeNotifier {
  void tick() => notifyListeners();
}
