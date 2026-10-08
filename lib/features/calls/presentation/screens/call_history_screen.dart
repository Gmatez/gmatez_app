import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/calling/call_status.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/pagination/cursor_page.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../domain/entities/call_session.dart';
import '../state/active_call_notifier.dart';

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  CursorPage<CallSession>? _page;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(callRepositoryProvider).history();
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      switch (result) {
        case Success(:final value):
          _page = value;
        case Failure(:final failure):
          _error = failure.userMessage;
      }
    });
  }

  Future<void> _redial(CallSession call, String callType) async {
    final myId = ref.read(authNotifierProvider).user?.id;
    final peerId = call.callerId == myId ? call.calleeId : call.callerId;
    final result = await ref
        .read(activeCallProvider.notifier)
        .startCall(calleeId: peerId, callType: callType);
    if (!mounted) {
      return;
    }
    switch (result) {
      case Success(:final value):
        await context.push(AppRoutes.callFor(value.id));
      case Failure(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.userMessage),
            action: (failure.code == 'WALLET_INSUFFICIENT_FUNDS' ||
                        failure.code == 'INSUFFICIENT_BALANCE') &&
                    ref.read(authNotifierProvider).user?.isActiveHost != true
                ? SnackBarAction(
                    label: 'Recharge',
                    onPressed: () => context.push(AppRoutes.wallet),
                  )
                : null,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authNotifierProvider).user?.id;
    final items = _page?.items ?? const <CallSession>[];
    final isEmpty = !_loading && _error == null && items.isEmpty;

    return MistScaffold(
      body: SafeArea(
        child: AppLayout.constrain(
          context,
          child: AsyncBody(
            loading: _loading,
            error: _error,
            onRetry: _load,
            empty: isEmpty,
            emptyIcon: Icons.call_outlined,
            emptyMessage: 'Discover a listener and start talking.',
            skeleton: const ScreenSkeleton.list(),
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: AppLayout.pagePadding(context).copyWith(
                  top: AppSpacing.md,
                  bottom: AppSpacing.lg,
                ),
                children: [
                  const ScreenHeader(
                    title: 'Calls',
                    subtitle: 'Tap to redial voice or video',
                  ),
                  StaggeredList(
                    children: [
                      for (final call in items)
                        FadeInUp(
                          child: _HistoryRow(
                            call: call,
                            myId: myId,
                            onVoice: () => _redial(call, 'VOICE'),
                            onVideo: () => _redial(call, 'VIDEO'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.call,
    required this.myId,
    required this.onVoice,
    required this.onVideo,
  });

  final CallSession call;
  final String? myId;
  final VoidCallback onVoice;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
    final mine = call.callerId == myId;
    final name = mine
        ? (call.calleeDisplayName ?? 'User')
        : (call.callerDisplayName ?? 'User');
    final missed = call.status.isTerminal && call.status.name != 'ended';
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          UserAvatar(name: name, size: 46),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: missed ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
                Text(
                  [
                    call.direction ?? (mine ? 'outgoing' : 'incoming'),
                    call.status.name,
                    if (call.settlementStatus != CallSettlementStatus.pending)
                      call.settlementStatus.name,
                    call.isVideo ? 'Video' : 'Audio',
                    _ago(call.createdAt),
                    if (mine)
                      '${((call.billedAmountCents) / 10).round()} cr'
                    else if (call.creatorEarningCents != null)
                      '+${((call.creatorEarningCents!) / 10).round()} cr earned',
                  ].join(' · '),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Voice call',
            onPressed: onVoice,
            icon: const Icon(Icons.call_rounded, color: AppColors.primary),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: onVideo,
            icon: const Icon(Icons.videocam_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

String _ago(DateTime? time) {
  if (time == null) {
    return 'recently';
  }
  final delta = DateTime.now().difference(time);
  if (delta.inMinutes < 60) {
    return '${delta.inMinutes.clamp(1, 59)} min ago';
  }
  if (delta.inHours < 24) {
    return '${delta.inHours} hr ago';
  }
  if (delta.inDays == 1) {
    return 'yesterday';
  }
  return '${delta.inDays} days ago';
}
