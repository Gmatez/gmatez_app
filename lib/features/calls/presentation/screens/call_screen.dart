import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/calling/call_media_provider.dart';
import '../../../../core/calling/call_status.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../state/active_call_notifier.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, required this.callId, this.embedded = false});

  final String callId;

  /// Drawn over the current page. Must not pop the navigator underneath.
  final bool embedded;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen(activeCallProvider, (previous, next) {
      final left =
          previous?.active?.id == widget.callId &&
          next.active?.id != widget.callId &&
          next.incoming?.id != widget.callId;
      if (left && !widget.embedded && context.canPop()) {
        context.pop();
      }
    });

    final state = ref.watch(activeCallProvider);
    final call = state.active?.id == widget.callId ? state.active : null;
    final notifier = ref.read(activeCallProvider.notifier);
    final media = ref.watch(callMediaProvider);
    final me = ref.watch(authNotifierProvider).user?.id;
    final iAmCaller = me != null && me == call?.callerId;
    final peerName = iAmCaller
        ? (call?.calleeDisplayName ?? 'Listener')
        : (call?.callerDisplayName ?? 'Caller');
    final peerAvatar = iAmCaller
        ? call?.calleeAvatarUrl
        : call?.callerAvatarUrl;
    final status = call?.status ?? CallStatus.initiated;
    final rate = call?.ratePerMinuteCents ?? 0;
    final isVideo = call?.isVideo ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: ListenableBuilder(
        listenable: media.videoLayout,
        builder: (context, _) {
          final remoteVideo = isVideo ? media.buildRemoteVideo() : null;
          final localPreview = isVideo && state.cameraEnabled
              ? media.buildLocalPreview()
              : null;
          final mainVideo = remoteVideo ?? localPreview;
          final pip = remoteVideo != null ? localPreview : null;
          return Stack(
        fit: StackFit.expand,
        children: [
          if (mainVideo != null)
            Positioned.fill(child: mainVideo)
          else
            const ColoredBox(color: AppColors.backgroundDeep),
          if (mainVideo == null)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x59141A66),
                    Color(0xEB141A66),
                    AppColors.backgroundDeep,
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            )
          else ...[
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 160,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC141A66), Color(0x00141A66)],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xE6141A66), Color(0x00141A66)],
                  ),
                ),
              ),
            ),
          ],
          if (pip != null)
            Positioned(
              right: 16,
              top: 72,
              width: 110,
              height: 160,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: pip,
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          notifier.hideCallScreen();
                          if (!widget.embedded && context.canPop()) {
                            context.pop();
                          }
                        },
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        color: Colors.white,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: AppColors.tideGlow.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          isVideo ? 'Video' : 'Voice',
                          style: const TextStyle(
                            color: AppColors.primarySoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (mainVideo == null) ...[
                    const Spacer(),
                    UserAvatar(name: peerName, imageUrl: peerAvatar, size: 120),
                    const SizedBox(height: 18),
                  ],
                  Text(
                    peerName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.onDeep,
                      fontSize: mainVideo == null ? 28 : 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusLabel(status, state.mediaState),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (status == CallStatus.connected) ...[
                    const SizedBox(height: 6),
                    _CallClock(connectedAt: call?.connectedAt),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    rate > 0
                        ? '${(rate / 10).toStringAsFixed(0)} credits / min'
                        : 'Connecting secure session',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  if (state.permissionMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.permissionMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.warningSoft),
                    ),
                    TextButton(
                      onPressed: openAppSettings,
                      child: const Text('Open settings'),
                    ),
                  ],
                  if (call?.isMockProvider ?? true) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Preview mode · billing is live · media is simulated',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (status.isTerminal)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Billed ${call?.billedSeconds ?? 0}s · '
                        '${((call?.billedAmountCents ?? 0) / 10).round()} credits',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Control(
                        icon: state.muted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        label: state.muted ? 'Unmute' : 'Mute',
                        onTap: notifier.toggleMute,
                      ),
                      _Control(
                        icon: state.speakerOn
                            ? Icons.volume_up_rounded
                            : Icons.volume_down_rounded,
                        label: 'Speaker',
                        onTap: notifier.toggleSpeaker,
                      ),
                      if (isVideo) ...[
                        _Control(
                          icon: state.cameraEnabled
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                          label: 'Camera',
                          onTap: notifier.toggleCamera,
                        ),
                        _Control(
                          icon: Icons.cameraswitch_rounded,
                          label: 'Flip',
                          onTap: notifier.switchCamera,
                        ),
                      ],
                      _Control(
                        icon: Icons.call_end_rounded,
                        label: 'End',
                        color: AppColors.danger,
                        onTap: () async {
                          await notifier.hangUp();
                          if (!widget.embedded &&
                              context.mounted &&
                              context.canPop()) {
                            context.pop();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
        },
      ),
    );
  }

  String _statusLabel(CallStatus status, CallMediaConnectionState media) {
    if (media == CallMediaConnectionState.reconnecting) {
      return 'Reconnecting…';
    }
    if (media == CallMediaConnectionState.failed) {
      return 'Media failed';
    }
    return switch (status) {
      CallStatus.initiated || CallStatus.ringing => 'Ringing…',
      CallStatus.accepted || CallStatus.connecting => 'Connecting…',
      CallStatus.connected => 'Connected',
      CallStatus.ended => 'Call ended',
      CallStatus.rejected => 'Rejected',
      CallStatus.cancelled => 'Cancelled',
      CallStatus.timeout => 'No answer',
      CallStatus.failed => 'Call failed',
    };
  }

}

class _CallClock extends StatefulWidget {
  const _CallClock({required this.connectedAt});

  final DateTime? connectedAt;

  @override
  State<_CallClock> createState() => _CallClockState();
}

class _CallClockState extends State<_CallClock> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final started = widget.connectedAt;
    final elapsed = started == null
        ? Duration.zero
        : DateTime.now().difference(started);
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = elapsed.inHours;
    final label = h > 0 ? '$h:$m:$s' : '$m:$s';
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.tideGlow,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color ??
              AppColors.onDeep.withValues(alpha: 0.1),
          elevation: color == null ? 0 : 2,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 58,
              height: 58,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
