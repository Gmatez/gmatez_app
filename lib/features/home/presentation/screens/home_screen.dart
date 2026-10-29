import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../app/shell/app_shell.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/constants/speaking_languages.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/enterprise_widgets.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../../calls/domain/entities/call_session.dart';
import '../../../calls/presentation/state/active_call_notifier.dart';
import '../../../calls/presentation/state/call_rate_provider.dart';
import '../../../discovery/domain/repositories/discovery_repository.dart';
import '../../../discovery/presentation/state/discovery_notifier.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../wallet/presentation/screens/wallet_screen.dart';
import '../widgets/promo_banner_carousel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  WalletSnapshot? _wallet;
  List<CallSession> _calls = const [];
  List<UserProfile> _hosts = const [];
  List<PromoBanner> _banners = const [];
  bool _loading = true;
  bool _onlineOnly = true;
  String? _language;
  String? _error;

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
    final results = await Future.wait([
      ref.read(apiClientProvider).get(
        ApiPaths.wallet,
        parser: (data) => WalletSnapshot.fromJson(asMap(data)),
      ),
      ref.read(callRepositoryProvider).history(),
      ref.read(discoveryRepositoryProvider).feed(
        DiscoveryQuery(
          limit: 12,
          onlineOnly: _onlineOnly,
          language: _language,
        ),
      ),
      ref.read(apiClientProvider).get(
        ApiPaths.banners,
        parser: (data) => asMapList(data)
            .map(PromoBanner.fromJson)
            .where((b) => b.id.isNotEmpty && b.title.isNotEmpty)
            .toList(),
      ),
    ]);
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      final wallet = results[0] as Result<WalletSnapshot>;
      final history = results[1] as Result<dynamic>;
      final feed = results[2] as Result<dynamic>;
      final banners = results[3] as Result<List<PromoBanner>>;
      if (wallet case Success(:final value)) {
        _wallet = value;
      } else if (wallet case Failure(:final failure)) {
        _error ??= failure.userMessage;
      }
      if (history case Success(:final value)) {
        final items = (value as dynamic).items as List;
        _calls = items.whereType<CallSession>().take(4).toList();
      }
      if (feed case Success(:final value)) {
        final items = (value as dynamic).items as List;
        _hosts = items.whereType<UserProfile>().toList();
      }
      if (banners case Success(:final value)) {
        _banners = value;
      }
    });
  }

  void _openDiscover(String callType) {
    context.go('${AppRoutes.discover}?callType=$callType');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final name = user?.displayName?.split(' ').first ?? 'there';
    final credits = creditsFromCents(_wallet?.availableBalanceCents);
    final held = creditsFromCents(_wallet?.heldBalanceCents ?? 0);
    final pad = AppLayout.pagePadding(context);

    return MistScaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(pad.left, 6, pad.right, 32),
            children: [
              FadeInUp(
                child: Row(
                  children: [
                    const Expanded(child: GmatezBrandMark(compact: true)),
                    IconButton(
                      tooltip: AppStrings.of(context)('wallet'),
                      onPressed: () => context.go(AppRoutes.wallet),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: AppStrings.of(context)('notifications'),
                      onPressed: () => context.push(AppRoutes.notifications),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FadeInUp(
                delay: const Duration(milliseconds: 40),
                child: Text(
                  'Good to see you, $name',
                  style: GoogleFonts.figtree(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FadeInUp(
                delay: const Duration(milliseconds: 60),
                child: Text(
                  'Secure voice & video calling with live listeners.',
                  style: GoogleFonts.figtree(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              if (!_loading && _banners.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                PromoBannerCarousel(
                  key: const ValueKey('home-promo-banners'),
                  banners: _banners,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (_loading)
                const ScreenSkeleton.home(
                  padding: EdgeInsets.zero,
                )
              else ...[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EnterpriseEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Couldn’t refresh',
                      message: _error!,
                      actionLabel: 'Retry',
                      onAction: _load,
                    ),
                  ),
                FadeInUp(
                  delay: const Duration(milliseconds: 80),
                  child: PressableScale(
                    onTap: () => context.go(AppRoutes.wallet),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: AppColors.creditGradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.22),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available balance',
                                  style: GoogleFonts.figtree(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$credits credits',
                                  style: GoogleFonts.figtree(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                if ((_wallet?.heldBalanceCents ?? 0) > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '$held held on active calls',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () => context.go(AppRoutes.wallet),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryDim,
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 40),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            child: const Text('Top up'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FadeInUp(
                  delay: const Duration(milliseconds: 110),
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.call_rounded,
                          label: 'Audio call',
                          onTap: () => _openDiscover('VOICE'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.videocam_rounded,
                          label: 'Video call',
                          onTap: () => _openDiscover('VIDEO'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.explore_rounded,
                          label: 'Discover',
                          onTap: () => context.go(AppRoutes.discover),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FadeInUp(
                  delay: const Duration(milliseconds: 130),
                  child: SectionLabel(
                    'Recent activity',
                    trailing: TextButton(
                      onPressed: () => context.go(AppRoutes.calls),
                      child: const Text('View all'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_calls.isEmpty)
                  EnterpriseEmptyState(
                    icon: Icons.phone_in_talk_outlined,
                    title: 'No calls yet',
                    message:
                        'Browse online listeners and start a secure voice or video session.',
                    actionLabel: 'Find listeners',
                    onAction: () => context.go(AppRoutes.discover),
                  )
                else
                  ..._calls.map(
                    (call) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RecentCallTile(call: call, myId: user?.id),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                FadeInUp(
                  delay: const Duration(milliseconds: 150),
                  child: SectionLabel(
                    _onlineOnly ? 'Online now' : 'Listeners',
                    trailing: TextButton(
                      onPressed: () => context.go(AppRoutes.discover),
                      child: const Text('Browse'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Online'),
                        selected: _onlineOnly,
                        onSelected: (selected) {
                          setState(() => _onlineOnly = selected);
                          _load();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('All languages'),
                        selected: _language == null,
                        onSelected: (_) {
                          setState(() => _language = null);
                          _load();
                        },
                      ),
                      for (final entry in speakingLanguages.entries) ...[
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Text(entry.value),
                          selected: _language == entry.key,
                          onSelected: (_) {
                            setState(() => _language = entry.key);
                            _load();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_hosts.isEmpty)
                  EnterpriseEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No listeners online',
                    message:
                        'Check back shortly, or open Discover to browse everyone available.',
                    actionLabel: 'Open Discover',
                    onAction: () => context.go(AppRoutes.discover),
                  )
                else
                  ..._hosts.take(5).map(
                    (host) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _OnlineHostTile(
                        host: host,
                        userRateCents: ref.watch(userCallRateProvider).value,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.figtree(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentCallTile extends ConsumerWidget {
  const _RecentCallTile({required this.call, required this.myId});

  final CallSession call;
  final String? myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = call.callerId == myId;
    final name = mine
        ? (call.calleeDisplayName ?? 'User')
        : (call.callerDisplayName ?? 'User');
    final peerId = mine ? call.calleeId : call.callerId;
    final missed = const {
      'TIMEOUT',
      'REJECTED',
      'FAILED',
      'CANCELLED',
    }.contains(call.status.name.toUpperCase());
    final subtitle = missed
        ? 'Missed · ${_ago(call.createdAt)}'
        : '${call.isVideo ? 'Video' : 'Audio'} · ${_ago(call.createdAt)}';

    return EnterpriseListTile(
      leading: UserAvatar(name: name, size: 42),
      title: name,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (missed)
            const StatusBadge(label: 'Missed', tone: StatusBadgeTone.danger)
          else
            StatusBadge(
              label: call.isVideo ? 'Video' : 'Audio',
              tone: StatusBadgeTone.brand,
            ),
          IconButton(
            tooltip: 'Call back',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              final result = await ref
                  .read(activeCallProvider.notifier)
                  .startCall(
                    calleeId: peerId,
                    callType: call.isVideo ? 'VIDEO' : 'VOICE',
                  );
              if (!context.mounted) return;
              if (result case Success(:final value)) {
                await context.push(AppRoutes.callFor(value.id));
              }
            },
            icon: const Icon(Icons.call_rounded, color: AppColors.primary),
          ),
        ],
      ),
      onTap: () => context.push(AppRoutes.profileFor(peerId)),
    );
  }
}

class _OnlineHostTile extends StatelessWidget {
  const _OnlineHostTile({required this.host, this.userRateCents});

  final UserProfile host;
  final int? userRateCents;

  @override
  Widget build(BuildContext context) {
    final rate = displayRateCents(host.ratePerMinuteCents, userRateCents);
    final rateLabel = rate > 0 ? '${(rate / 10).round()} cr/min' : 'Ask for rates';
    final languages = host.languages
        .map((code) => speakingLanguages[code] ?? code)
        .take(3)
        .join(' · ');
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(AppRoutes.profileFor(host.userId)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              UserAvatar(
                name: host.displayName,
                imageUrl: host.avatarUrl,
                online: host.online,
                size: 58,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      host.bio.isEmpty ? 'Ready for a conversation' : host.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniTag(
                          icon: host.online ? Icons.circle : Icons.circle_outlined,
                          label: host.online ? 'Online' : 'Away',
                        ),
                        if (languages.isNotEmpty)
                          _MiniTag(icon: Icons.translate_rounded, label: languages),
                        _MiniTag(icon: Icons.payments_outlined, label: rateLabel),
                        if (host.voiceEnabled)
                          const _MiniTag(icon: Icons.call_rounded, label: 'Voice'),
                        if (host.videoEnabled)
                          const _MiniTag(icon: Icons.videocam_rounded, label: 'Video'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
  if (delta.inMinutes < 1) {
    return 'just now';
  }
  if (delta.inMinutes < 60) {
    return '${delta.inMinutes}m ago';
  }
  if (delta.inHours < 24) {
    return '${delta.inHours}h ago';
  }
  if (delta.inDays == 1) {
    return 'yesterday';
  }
  return '${delta.inDays}d ago';
}
