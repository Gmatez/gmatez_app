import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/calling/call_media_provider.dart';
import '../../../../core/calling/call_status.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../state/active_call_notifier.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, required this.callId});

  final String callId;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final call = ref.read(activeCallProvider).active;
      if (call?.id != widget.callId || call?.connectedAt == null) {
        return;
      }
      setState(() {
        _elapsed = DateTime.now().difference(call!.connectedAt!);
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeCallProvider, (previous, next) {
      final left =
          previous?.active?.id == widget.callId &&
          next.active?.id != widget.callId &&
          next.incoming?.id != widget.callId;
      if (left && context.canPop()) {
        context.pop();
      }
    });

    final state = ref.watch(activeCallProvider);
    final call = state.active?.id == widget.callId ? state.active : null;
    final notifier = ref.read(activeCallProvider.notifier);
    final media = ref.watch(callMediaProvider);
    final peerName =
        call?.calleeDisplayName ?? call?.callerDisplayName ?? 'Connecting…';
    final peerAvatar = call?.calleeAvatarUrl ?? call?.callerAvatarUrl;
    final status = call?.status ?? CallStatus.initiated;
    final rate = call?.ratePerMinuteCents ?? 0;
    final isVideo = call?.isVideo ?? false;
    final remoteVideo = isVideo ? media.buildRemoteVideo() : null;
    final localPreview = isVideo ? media.buildLocalPreview() : null;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (remoteVideo != null)
            Positioned.fill(child: remoteVideo)
          else
            const ColoredBox(color: AppColors.backgroundDeep),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.backgroundDeep.withValues(alpha: 0.35),
                  AppColors.backgroundDeep.withValues(alpha: 0.92),
                  AppColors.backgroundDeep,
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          if (localPreview != null && state.cameraEnabled)
            Positioned(
              right: 16,
              top: 72,
              width: 110,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: localPreview,
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
                        onPressed: () => context.pop(),
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
                  if (remoteVideo == null) ...[
                    const Spacer(),
                    UserAvatar(name: peerName, imageUrl: peerAvatar, size: 120),
                    const SizedBox(height: 18),
                  ] else
                    const Spacer(),
                  Text(
                    peerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.onDeep,
                      fontSize: 28,
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
                    Text(
                      _formatDuration(_elapsed),
                      style: const TextStyle(
                        color: AppColors.tideGlow,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
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
                          if (context.mounted && context.canPop()) {
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

  String _formatDuration(Duration value) {
    final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = value.inHours;
    if (h > 0) {
      return '$h:$m:$s';
    }
    return '$m:$s';
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
