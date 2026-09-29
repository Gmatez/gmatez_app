import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';

class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
  final _amount = TextEditingController();
  final _upi = TextEditingController();
  final _label = TextEditingController(text: 'Primary');
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _destinations = const [];
  int _available = 0;
  bool _loading = true;
  bool _submitting = false;
  bool _savingDest = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _amount.dispose();
    _upi.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final wallet = await ref
        .read(apiClientProvider)
        .get(ApiPaths.wallet, parser: asMap);
    final payouts = await ref
        .read(apiClientProvider)
        .get(ApiPaths.payouts, parser: asMapList);
    final destinations = await ref
        .read(apiClientProvider)
        .get(ApiPaths.payoutDestinations, parser: asMapList);
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      if (wallet case Success(:final value)) {
        _available = asInt(value['availableBalanceCents']);
        if (_amount.text.isEmpty) {
          _amount.text = '$_available';
        }
      } else if (wallet case Failure(:final failure)) {
        _error = failure.userMessage;
      }
      if (payouts case Success(:final value)) {
        _items = value;
      } else if (payouts case Failure(:final failure)) {
        _error ??= failure.userMessage;
      }
      if (destinations case Success(:final value)) {
        _destinations = value;
      } else if (destinations case Failure(:final failure)) {
        _error ??= failure.userMessage;
      }
    });
  }

  Future<void> _saveDestination() async {
    final upi = _upi.text.trim();
    if (upi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a UPI ID or account handle')),
      );
      return;
    }
    setState(() => _savingDest = true);
    final result = await ref
        .read(apiClientProvider)
        .post(
          ApiPaths.payoutDestinations,
          body: {
            'type': 'UPI',
            'label': _label.text.trim().isEmpty ? 'Primary' : _label.text.trim(),
            'details': {'upiId': upi},
          },
          parser: asMap,
        );
    if (!mounted) {
      return;
    }
    setState(() => _savingDest = false);
    if (result case Failure(:final failure)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout destination saved')),
      );
      _upi.clear();
    }
    await _load();
  }

  Future<void> _request() async {
    if (_destinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a payout destination before requesting'),
        ),
      );
      return;
    }
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    setState(() => _submitting = true);
    final result = await ref
        .read(apiClientProvider)
        .post(
          ApiPaths.payouts,
          body: {'amountCents': amount, 'idempotencyKey': const Uuid().v4()},
          parser: asMap,
        );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (result case Failure(:final failure)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payout requested. Status stays Requested until admin processing completes.',
          ),
        ),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return MistScaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: AsyncBody(
        loading: _loading,
        error: _error,
        onRetry: _load,
        skeleton: const ScreenSkeleton.wallet(),
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
                        colors: AppColors.creditGradient,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatCents(_available),
                          style: const TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Available for payout',
                          style: TextStyle(
                            color: AppColors.onPrimary.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Minimum payout is \$5.00. Completion is confirmed by the backend, never locally.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('Destination'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_destinations.isEmpty)
                        const EmptyState(
                          icon: Icons.account_balance_outlined,
                          title: 'No destination',
                          message: 'Add a UPI ID or handle below.',
                        )
                      else
                        ..._destinations.map((row) {
                          final details = row['detailsJson'];
                          final detailText = details is Map
                              ? details.values
                                    .map((e) => e.toString())
                                    .join(' · ')
                              : '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.payments_outlined,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${row['type'] ?? ''} · ${row['label'] ?? ''}'
                                            '${row['isDefault'] == true ? ' (default)' : ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (detailText.isNotEmpty)
                                        Text(
                                          detailText,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      AppTextField(
                        controller: _label,
                        label: 'Label',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _upi,
                        label: 'UPI ID / handle',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: _savingDest ? 'Saving…' : 'Save destination',
                        loading: _savingDest,
                        variant: AppButtonVariant.secondary,
                        onPressed: _saveDestination,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('Request payout'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _amount,
                        label: 'Amount (cents)',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: _submitting ? 'Requesting…' : 'Request payout',
                        loading: _submitting,
                        onPressed: _request,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('History'),
                const SizedBox(height: AppSpacing.sm),
                if (_items.isEmpty)
                  const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'No payouts yet',
                    message: 'Your payout requests will appear here.',
                  )
                else
                  ..._items.map((row) {
                    final reason = row['failureReason'] ?? row['reviewNote'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${formatCents(asInt(row['amountCents']))} · ${row['status'] ?? ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              [
                                row['createdAt'] ?? '',
                                if (reason != null) reason.toString(),
                              ].join(' · '),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
