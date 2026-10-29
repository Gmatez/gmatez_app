import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _recent = const [];
  bool _loading = true;
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
    final dashboard = await ref
        .read(apiClientProvider)
        .get(ApiPaths.hostsDashboard, parser: asMap);
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      switch (dashboard) {
        case Failure(:final failure):
          _error = failure.userMessage;
        case Success(:final value):
          _stats = asMap(value['stats']);
          _recent = asMapList(value['recentCalls']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final available = formatCents(asInt(_stats?['availableBalanceCents']));
    final lifetime = formatCents(asInt(_stats?['lifetimeEarnedCents']));

    return MistScaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context)('earnings')),
        automaticallyImplyLeading: false,
      ),
      body: AsyncBody(
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
                top: AppSpacing.sm,
                bottom: AppSpacing.xl,
              ),
              children: [
                FadeInUp(
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: AppColors.creditGradient,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.softShadow,
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          available,
                          style: const TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Available to withdraw',
                          style: TextStyle(
                            color: AppColors.onPrimary.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$lifetime lifetime earned',
                          style: TextStyle(
                            color: AppColors.onPrimary.withValues(alpha: 0.72),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                StaggeredList(
                  children: [
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        _Stat(
                          'Today',
                          formatCents(asInt(_stats?['todayEarnedCents'])),
                        ),
                        _Stat(
                          'This week',
                          formatCents(asInt(_stats?['weekEarnedCents'])),
                        ),
                        _Stat(
                          'This month',
                          formatCents(asInt(_stats?['monthEarnedCents'])),
                        ),
                        _Stat(
                          'Pending payout',
                          formatCents(asInt(_stats?['pendingPayoutCents'])),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Request payout',
                  icon: Icons.payments_outlined,
                  onPressed: () => context.push(AppRoutes.payouts),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('Recent call earnings'),
                const SizedBox(height: AppSpacing.sm),
                if (_recent.isEmpty)
                  const EmptyState(
                    icon: Icons.phone_in_talk_outlined,
                    title: 'No earnings yet',
                    message: 'Settled calls will appear here with amounts.',
                  )
                else
                  ..._recent.map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${row['callType'] ?? 'CALL'} · ${row['status'] ?? ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
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
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: AppCard(
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
