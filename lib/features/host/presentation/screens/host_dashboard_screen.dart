import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/result.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../../calls/presentation/state/active_call_notifier.dart';

class HostDashboardScreen extends ConsumerStatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  ConsumerState<HostDashboardScreen> createState() =>
      _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen> {
  Map<String, dynamic>? _data;
  StreamSubscription<RealtimeEvent>? _sub;
  bool _loading = true;
  bool _toggling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sub = ref.read(realtimeServiceProvider).events.listen((event) {
        if (event.name == 'host.availability.updated' ||
            event.name == 'wallet.updated' ||
            event.name == 'call.ended') {
          unawaited(_load(silent: true));
        }
      });
      _load();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final result = await ref
        .read(apiClientProvider)
        .get(ApiPaths.hostsDashboard, parser: asMap);
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      switch (result) {
        case Success(:final value):
          _data = value;
        case Failure(:final failure):
          if (!silent) {
            _error = failure.userMessage;
          }
      }
    });
    await ref.read(authNotifierProvider.notifier).refreshUser();
  }

  Future<void> _setAvailability(String availability) async {
    setState(() => _toggling = true);
    final result = await ref.read(apiClientProvider).post(
      ApiPaths.hostsAvailability,
      body: {'availability': availability},
      parser: (_) {},
    );
    if (!mounted) {
      return;
    }
    setState(() => _toggling = false);
    if (result case Failure(:final failure)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage)));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final host = asMap(_data?['host']);
    final stats = asMap(_data?['stats']);
    final recent = asMapList(_data?['recentCalls']);
    final availability = host['availability'] as String? ?? 'OFFLINE';
    final name = ref.watch(authNotifierProvider).user?.displayName ?? 'Listener';

    return MistScaffold(
      body: SafeArea(
        child: AsyncBody(
        loading: _loading,
        error: _error,
        onRetry: _load,
        skeleton: const ScreenSkeleton.dashboard(),
        child: RefreshIndicator(
          onRefresh: _load,
          child: AppLayout.constrain(
            context,
            child: ListView(
              padding: AppLayout.pagePadding(context).copyWith(
                top: 8,
                bottom: 28,
              ),
              children: [
                ScreenHeader(
                  title: 'Listener studio',
                  subtitle: 'Hi $name',
                  action: IconButton(
                    onPressed: () => context.push(AppRoutes.notifications),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
              const SizedBox(height: 16),
              if (asMap(_data?['completeness']).isNotEmpty) ...[
                _CompletenessCard(completeness: asMap(_data?['completeness'])),
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: availability == 'BUSY'
                    ? () => ref
                          .read(activeCallProvider.notifier)
                          .showCallScreen()
                    : null,
                child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: availability == 'ONLINE'
                        ? const [Color(0xFF16A34A), Color(0xFF22C55E)]
                        : availability == 'PAUSED'
                        ? const [Color(0xFFCA8A04), Color(0xFFEAB308)]
                        : AppColors.creditGradient,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      availability == 'ONLINE'
                          ? 'You are online'
                          : availability == 'PAUSED'
                          ? 'You are paused'
                          : availability == 'BUSY'
                          ? 'On a call'
                          : 'You are offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      availability == 'ONLINE'
                          ? 'Callers can find you in Discover right now.'
                          : availability == 'PAUSED'
                          ? 'You are temporarily unavailable for new calls.'
                          : availability == 'BUSY'
                          ? 'Tap to open the call. Availability returns when it ends.'
                          : 'Go online when you are ready to take calls.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                    if (availability != 'BUSY') ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in const [
                            'ONLINE',
                            'PAUSED',
                            'OFFLINE',
                          ])
                            FilledButton(
                              onPressed: _toggling || availability == option
                                  ? null
                                  : () => _setAvailability(option),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                              ),
                              child: Text(
                                _toggling && availability != option
                                    ? 'Updating…'
                                    : option == 'ONLINE'
                                    ? 'Go online'
                                    : option == 'PAUSED'
                                    ? 'Pause'
                                    : 'Go offline',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Today',
                      value: '${stats['todayCallCount'] ?? 0} calls',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Minutes',
                      value:
                          '${(asInt(stats['todayBilledSeconds']) / 60).ceil()}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Earned today',
                      value: formatCents(asInt(stats['todayEarnedCents'])),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Available',
                      value: formatCents(asInt(stats['availableBalanceCents'])),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionLabel('Quick tools'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ToolChip(
                    icon: Icons.payments_outlined,
                    label: 'Earnings',
                    onTap: () => context.push(AppRoutes.earnings),
                  ),
                  _ToolChip(
                    icon: Icons.account_balance_outlined,
                    label: 'Payouts',
                    onTap: () => context.push(AppRoutes.payouts),
                  ),
                  _ToolChip(
                    icon: Icons.tune_rounded,
                    label: 'Rates',
                    onTap: () => context.push(AppRoutes.hostCallSettings),
                  ),
                  _ToolChip(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                    onTap: () => context.push(AppRoutes.editProfile),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const SectionLabel('Recent calls'),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                const EmptyState(
                  icon: Icons.phone_callback_outlined,
                  title: 'No calls yet',
                  message:
                      'Go online to start receiving listener calls.',
                )
              else
                ...recent.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row['callType'] ?? 'CALL'} · ${row['status'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${row['createdAt'] ?? ''}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatCents(asInt(row['billedAmountCents'])),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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

class _CompletenessCard extends StatelessWidget {
  const _CompletenessCard({required this.completeness});

  final Map<String, dynamic> completeness;

  @override
  Widget build(BuildContext context) {
    final percentage = asInt(completeness['percentage']);
    final isComplete = completeness['isComplete'] == true;
    final missing =
        (completeness['missingFields'] as List?)?.whereType<String>().toList() ??
        const [];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isComplete
                ? 'Profile complete'
                : 'Profile $percentage% complete',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (!isComplete && missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Missing: ${missing.join(', ')}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
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
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: SizedBox(
          width: 104,
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
