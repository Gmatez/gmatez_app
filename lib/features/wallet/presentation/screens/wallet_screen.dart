import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/pagination/cursor_page.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/result.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/razorpay_checkout.dart';
import '../../domain/recharge_plan.dart';
import '../../domain/top_up_flow.dart';

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
  String? _plansError;
  List<RechargePlan> _plans = const [];
  int _selectedPack = 0;

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
    final plans = await _api.get(
      ApiPaths.rechargePlans,
      parser: (data) => asMapList(data)
          .map(RechargePlan.fromJson)
          .where((plan) => plan.id.isNotEmpty && plan.priceMinor > 0)
          .toList(),
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
      if (plans case Success(:final value)) {
        _plans = value;
        _plansError = null;
        if (_selectedPack >= value.length) {
          _selectedPack = 0;
        }
      } else if (plans case Failure(:final failure)) {
        _plans = const [];
        _plansError = failure.userMessage;
      }
    });
  }

  Future<void> _buy(RechargePlan plan) async {
    setState(() => _buying = true);
    final intent = await _api.post(
      ApiPaths.paymentIntents,
      body: {
        'rechargePlanId': plan.id,
        'idempotencyKey': const Uuid().v4(),
      },
      parser: (data) =>
          data is Map<String, dynamic> ? data : <String, dynamic>{},
    );
    if (intent case Success(:final value)) {
      final message = await _finishIntent(value);
      if (mounted && message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } else if (intent case Failure(:final failure)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.userMessage)));
      }
    }
    if (mounted) {
      setState(() => _buying = false);
    }
    await _load();
  }

  Future<String?> _finishIntent(Map<String, dynamic> value) async {
    final id = value['id'] as String?;
    final provider = value['provider'] as String? ?? '';
    if (id == null) {
      return topUpMessageText(TopUpMessage.failed);
    }
    if (provider != 'razorpay') {
      return topUpMessageText(TopUpMessage.pendingConfirmation);
    }
    final checkout = asMap(value['checkout']);
    final opened = await RazorpayCheckout().open(
      RazorpayCheckoutRequest(
        keyId: checkout['keyId'] as String? ?? '',
        orderId: checkout['orderId'] as String? ?? '',
        amountPaise: asInt(checkout['amount']),
        currency: checkout['currency'] as String? ?? 'INR',
      ),
    );
    if (opened.kind == CheckoutKind.success && opened.success != null) {
      final verified = await _api.post(
        ApiPaths.paymentVerify(id),
        body: {
          'razorpayOrderId': opened.success!.orderId,
          'razorpayPaymentId': opened.success!.paymentId,
          'razorpaySignature': opened.success!.signature,
        },
        parser: asMap,
      );
      final status = switch (verified) {
        Success(:final value) => value['status'] as String?,
        Failure() => 'FAILED',
      };
      return topUpMessageText(
        interpretTopUp(
          provider: provider,
          allowMock: false,
          serverStatus: status,
          checkout: opened.kind,
        ),
      );
    }
    if (opened.kind == CheckoutKind.cancelled ||
        opened.kind == CheckoutKind.failed) {
      final abandoned = await _api.post(
        ApiPaths.paymentAbandon(id),
        parser: asMap,
      );
      final status = switch (abandoned) {
        Success(:final value) => value['status'] as String?,
        Failure() => null,
      };
      return topUpMessageText(
        interpretTopUp(
          provider: provider,
          allowMock: false,
          serverStatus: status,
          checkout: opened.kind,
        ),
      );
    }
    return topUpMessageText(
      interpretTopUp(
        provider: provider,
        allowMock: false,
        serverStatus: null,
        checkout: opened.kind,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final credits = creditsFromCents(_wallet?.availableBalanceCents);
    final isListener =
        ref.watch(authNotifierProvider).user?.isActiveHost == true;
    final currency = _wallet?.currency ?? 'INR';
    return MistScaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(AppStrings.of(context)('recharge')),
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6D8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: Color(0xFFE0A106), size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '$credits',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3D4FFF), Color(0xFF6C4DFF)],
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 36),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Your balance', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                                    Text('$credits credits', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.add_card_rounded, color: Colors.white),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if ((_wallet?.heldBalanceCents ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'On hold · ${creditsFromCents(_wallet!.heldBalanceCents)} credits',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (isListener)
                          EmptyState(
                            icon: Icons.headphones_rounded,
                            title: AppStrings.of(context)('listenerWallet'),
                            message: AppStrings.of(context)('listenerWalletMessage'),
                            actionLabel: AppStrings.of(context)('viewEarnings'),
                            onAction: () => context.push(AppRoutes.earnings),
                          )
                        else ...[
                          const _RechargePromo(),
                          const SizedBox(height: 22),
                          const Text(
                            'Recharge Plans',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16324F),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_plansError != null)
                            EmptyState(
                              icon: Icons.wifi_off_rounded,
                              title: 'Plans unavailable',
                              message: _plansError!,
                            )
                          else if (_plans.isEmpty)
                            const EmptyState(
                              icon: Icons.payments_outlined,
                              title: 'No recharge plans',
                              message:
                                  'Active plans from the admin panel will show here.',
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _plans.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.72,
                                  ),
                              itemBuilder: (context, i) {
                                final item = _plans[i];
                                return _PlanTile(
                                  plan: item,
                                  currency: currency,
                                  busy: _buying && i == _selectedPack,
                                  enabled: !_buying,
                                  onBuy: () {
                                    setState(() => _selectedPack = i);
                                    _buy(item);
                                  },
                                );
                              },
                            ),
                        ],
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RechargePromo extends StatelessWidget {
  const _RechargePromo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F6FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Don't Let the Moment End.",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16324F),
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Recharge now and keep talking.',
                  style: TextStyle(
                    color: Color(0xFF5C6B7A),
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.savings_rounded, color: Color(0xFFE11D48), size: 54),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.currency,
    required this.busy,
    required this.enabled,
    required this.onBuy,
  });

  final RechargePlan plan;
  final String currency;
  final bool busy;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final coins = plan.coins;
    final badge = plan.badgeLabel;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.softShadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Column(
          children: [
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  badge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryDim,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              )
            else
              const SizedBox(height: 14),
            const SizedBox(height: 6),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF4CC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.monetization_on_rounded,
                color: Color(0xFFE0A106),
                size: 22,
              ),
            ),
            const Spacer(),
            Text(
              '$coins',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
            const Text(
              'coins',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (plan.bonusCredits > 0)
              Text(
                '+${plan.bonusCredits} bonus',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: FilledButton(
                onPressed: enabled ? onBuy : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        formatCents(plan.priceMinor, currency: currency),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
