import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/pagination/cursor_page.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/result.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/widgets/app_widgets.dart';

class WalletSnapshot {
  const WalletSnapshot({
    required this.currency,
    required this.availableBalanceCents,
    required this.heldBalanceCents,
  });

  final String currency;
  final int availableBalanceCents;
  final int heldBalanceCents;

  factory WalletSnapshot.fromJson(Map<String, dynamic> json) {
    return WalletSnapshot(
      currency: json['currency'] as String? ?? 'USD',
      availableBalanceCents: json['availableBalanceCents'] as int? ?? 0,
      heldBalanceCents: json['heldBalanceCents'] as int? ?? 0,
    );
  }
}

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  WalletSnapshot? _wallet;
  CursorPage<Map<String, dynamic>>? _ledger;
  StreamSubscription<RealtimeEvent>? _sub;
  bool _loading = true;
  bool _buying = false;
  String? _error;
  int _selectedPack = 1;

  ApiClient get _api => ref.read(apiClientProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sub = ref.read(realtimeServiceProvider).events.listen((event) {
        if (event.name == 'wallet.updated') {
          unawaited(_load());
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final wallet = await _api.get(
      ApiPaths.wallet,
      parser: (data) => WalletSnapshot.fromJson(asMap(data)),
    );
    final ledger = await _api.get(
      ApiPaths.walletLedger,
      parser: (data) => CursorPage.fromJson(data, (json) => json),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      if (wallet case Success(:final value)) {
        _wallet = value;
      } else if (wallet case Failure(:final failure)) {
        _error = failure.userMessage;
      }
      if (ledger case Success(:final value)) {
        _ledger = value;
      }
    });
  }

  Future<void> _buy(int amountCents) async {
    setState(() => _buying = true);
    final intent = await _api.post(
      ApiPaths.paymentIntents,
      body: {'amountCents': amountCents, 'idempotencyKey': const Uuid().v4()},
      parser: (data) =>
          data is Map<String, dynamic> ? data : <String, dynamic>{},
    );
    if (intent case Success(:final value)) {
      final id = value['id'] as String?;
      final provider = value['provider'] as String?;
      final config = ref.read(appConfigProvider);
      // TEST/DEV ONLY — never treat Flutter success as wallet credit in production.
      if (id != null &&
          provider == 'mock' &&
          config.allowsMockPayments) {
        await _api.post(ApiPaths.paymentSandboxConfirm(id), parser: (_) {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Credits added to your wallet.')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Complete this payment with your provider. Credits appear after server confirmation.',
            ),
          ),
        );
      }
    } else if (intent case Failure(:final failure)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.userMessage)));
      }
    }
    setState(() => _buying = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final credits = creditsFromCents(_wallet?.availableBalanceCents);
    final pack = _packs[_selectedPack];
    return MistScaffold(
      appBar: AppBar(
        title: const Text('Recharge'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: AsyncBody(
        loading: _loading,
        error: _error,
        onRetry: _load,
        skeleton: const ScreenSkeleton.wallet(),
        child: SafeArea(
          child: AppLayout.constrain(
            context,
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: AppLayout.pagePadding(context).copyWith(
                        top: 8,
                        bottom: 16,
                      ),
                      children: [
                        const ScreenHeader(
                          title: 'Calling credits',
                          subtitle:
                              'Add credits for audio and video calls',
                        ),
                        FadeInUp(
                          child: Container(
                            padding: const EdgeInsets.all(20),
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
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.onPrimary.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: AppColors.onPrimary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$credits credits',
                                        style: const TextStyle(
                                          color: AppColors.onPrimary,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        'Available balance',
                                        style: TextStyle(
                                          color: AppColors.onPrimary.withValues(
                                            alpha: 0.82,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if ((_wallet?.heldBalanceCents ?? 0) >
                                          0)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'On hold · ${creditsFromCents(_wallet!.heldBalanceCents)} credits',
                                            style: TextStyle(
                                              color: AppColors.onPrimary
                                                  .withValues(alpha: 0.72),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SectionLabel('Choose a pack'),
                        const SizedBox(height: 10),
                        StaggeredList(
                          children: [
                            for (var i = 0; i < _packs.length; i++)
                              _PackCard(
                                pack: _packs[i],
                                selected: i == _selectedPack,
                                onTap: () => setState(() => _selectedPack = i),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const SectionLabel('Recent activity'),
                        const SizedBox(height: 8),
                        if (_ledger == null || _ledger!.items.isEmpty)
                          const EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No activity yet',
                            message:
                                'Purchases and call charges will show here.',
                          )
                        else
                          ..._ledger!.items.take(12).map((row) {
                            final amount = asInt(row['amountCents']);
                            final credit = row['type'] == 'CREDIT';
                            return Padding(
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${row['reason'] ?? 'ENTRY'}',
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
                                      '${credit ? '+' : '-'}${creditsFromCents(amount < 0 ? -amount : amount)} cr',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: credit
                                            ? AppColors.success
                                            : AppColors.textPrimary,
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
                Padding(
                  padding: AppLayout.pagePadding(context).copyWith(
                    top: 8,
                    bottom: 16,
                  ),
                  child: AppButton(
                    label: _buying
                        ? 'Working…'
                        : 'Recharge ${pack.credits + pack.bonus} credits',
                    loading: _buying,
                    onPressed: _buying ? null : () => _buy(pack.amountCents),
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

class _CreditPack {
  const _CreditPack({
    required this.name,
    required this.credits,
    required this.bonus,
    required this.priceLabel,
    required this.amountCents,
    this.recommended = false,
  });

  final String name;
  final int credits;
  final int bonus;
  final String priceLabel;
  final int amountCents;
  final bool recommended;
}

const _packs = [
  _CreditPack(
    name: 'Starter',
    credits: 100,
    bonus: 0,
    priceLabel: '₹99',
    amountCents: 1000,
  ),
  _CreditPack(
    name: 'Standard',
    credits: 500,
    bonus: 50,
    priceLabel: '₹399',
    amountCents: 5000,
    recommended: true,
  ),
  _CreditPack(
    name: 'Premium',
    credits: 1200,
    bonus: 200,
    priceLabel: '₹799',
    amountCents: 12000,
  ),
];

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.selected,
    required this.onTap,
  });

  final _CreditPack pack;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: AppColors.softShadow,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          pack.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (pack.recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'Recommended',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pack.credits} credits',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (pack.bonus > 0)
                      Text(
                        '+${pack.bonus} bonus credits',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                pack.priceLabel,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
        ),
      ),
    );
  }
}
