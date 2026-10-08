import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../state/active_call_notifier.dart';

class IncomingCallHost extends ConsumerStatefulWidget {
  const IncomingCallHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IncomingCallHost> createState() => _IncomingCallHostState();
}

class _IncomingCallHostState extends ConsumerState<IncomingCallHost> {
  String? _openedCallId;

  void _openCallScreen(String callId) {
    if (_openedCallId == callId || callId.isEmpty) {
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final path = router.state.uri.path;
    if (path == AppRoutes.callFor(callId) || path.startsWith('/call/$callId')) {
      _openedCallId = callId;
      return;
    }
    _openedCallId = callId;
    router.push(AppRoutes.callFor(callId));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeCallProvider, (previous, next) {
      final active = next.active;
      if (active == null ||
          active.status.isTerminal ||
          next.callScreenHidden) {
        _openedCallId = null;
        return;
      }
      final callId = active.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final current = ref.read(activeCallProvider);
        final open = current.active;
        if (open == null ||
            open.id != callId ||
            open.status.isTerminal ||
            current.callScreenHidden) {
          return;
        }
        _openCallScreen(callId);
      });
    });

    final incoming = ref.watch(activeCallProvider).incoming;
    return Stack(
      children: [
        widget.child,
        if (incoming != null)
          Positioned.fill(
            child: Material(
              color: AppColors.backgroundDeep.withValues(alpha: 0.96),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.backgroundDeep.withValues(alpha: 0.88),
                      AppColors.primaryDim.withValues(alpha: 0.35),
                      AppColors.backgroundDeep,
                    ],
                  ),
                ),
                child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                  child: Column(
                    children: [
                      Text(
                        incoming.isVideo
                            ? 'Incoming video call'
                            : 'Incoming voice call',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      PulseGlowAvatar(
                        name: incoming.callerDisplayName ?? 'Caller',
                        imageUrl: incoming.callerAvatarUrl,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        incoming.callerDisplayName ?? 'Someone is calling',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        incoming.isVideo
                            ? 'Video · Answer to connect'
                            : 'Voice · Answer to connect',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _RoundAction(
                            color: AppColors.danger,
                            icon: Icons.call_end_rounded,
                            label: 'Decline',
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              ref
                                  .read(activeCallProvider.notifier)
                                  .rejectIncoming();
                            },
                          ),
                          _RoundAction(
                            color: AppColors.primary,
                            icon: incoming.isVideo
                                ? Icons.videocam_rounded
                                : Icons.call_rounded,
                            label: 'Accept',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Future<void>(() async {
                                final result = await ref
                                    .read(activeCallProvider.notifier)
                                    .acceptIncoming();
                                if (result.isSuccess && context.mounted) {
                                  ref
                                      .read(activeCallProvider.notifier)
                                      .showCallScreen();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              ),
            ),
          ),
      ],
    );
  }
}

class PulseGlowAvatar extends StatefulWidget {
  const PulseGlowAvatar({super.key, required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  State<PulseGlowAvatar> createState() => _PulseGlowAvatarState();
}

class _PulseGlowAvatarState extends State<PulseGlowAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          padding: EdgeInsets.all(18 + (t * 8)),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.18 + (t * 0.12)),
          ),
          child: child,
        );
      },
      child: UserAvatar(
        name: widget.name,
        imageUrl: widget.imageUrl,
        size: 108,
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
