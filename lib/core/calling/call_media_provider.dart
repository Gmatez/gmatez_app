import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/widgets.dart';

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
  bool joined = false;
  bool muted = false;
  bool cameraEnabled = false;
  bool speakerEnabled = true;

  @override
  Stream<CallMediaConnectionState> get connectionStates => _states.stream;

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
  RtcEngine? _engine;
  bool _joining = false;
  bool _joined = false;
  int? _remoteUid;
  String? _appId;
  String? _channelName;
  bool _video = false;

  @override
  Stream<CallMediaConnectionState> get connectionStates => _states.stream;

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
    if (_joined || _joining) {
      return;
    }
    if (appId.isEmpty || channelName.isEmpty || token.isEmpty) {
      throw StateError('Missing Agora RTC credentials from server');
    }
    _joining = true;
    _video = video;
    _appId = appId;
    _channelName = channelName;
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
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            _remoteUid = remoteUid;
            _states.add(CallMediaConnectionState.connected);
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (_remoteUid == remoteUid) {
              _remoteUid = null;
            }
          },
          onConnectionStateChanged: (connection, state, reason) {
            switch (state) {
              case ConnectionStateType.connectionStateReconnecting:
                _states.add(CallMediaConnectionState.reconnecting);
              case ConnectionStateType.connectionStateConnected:
                _states.add(CallMediaConnectionState.connected);
              case ConnectionStateType.connectionStateFailed:
                _states.add(CallMediaConnectionState.failed);
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
            if (!_joined) {
              _states.add(CallMediaConnectionState.failed);
            }
          },
          onTokenPrivilegeWillExpire: (connection, token) {
            // ActiveCallNotifier renews via backend before expiry.
          },
        ),
      );

      await engine.enableAudio();
      await engine.setDefaultAudioRouteToSpeakerphone(true);
      if (video) {
        await engine.enableVideo();
        await engine.startPreview();
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
    } catch (e) {
      _joining = false;
      _states.add(CallMediaConnectionState.failed);
      await leave();
      rethrow;
    }
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
    final engine = _engine;
    _engine = null;
    _joined = false;
    _joining = false;
    _remoteUid = null;
    _channelName = null;
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
    final engine = _engine;
    final appId = _appId;
    if (engine == null || appId == null || !_video) {
      return null;
    }
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  @override
  Widget? buildRemoteVideo() {
    final engine = _engine;
    final remote = _remoteUid;
    final channel = _channelName;
    if (engine == null || remote == null || channel == null || !_video) {
      return null;
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: remote),
        connection: RtcConnection(channelId: channel),
      ),
    );
  }
}
