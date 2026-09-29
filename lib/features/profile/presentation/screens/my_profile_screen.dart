import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../../settings/presentation/screens/legal_screen.dart';
import '../../../wallet/presentation/screens/wallet_screen.dart';
import '../state/profile_notifier.dart';
import '../state/profile_state.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  int? _credits;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myProfileNotifierProvider.notifier).load();
      _loadWallet();
    });
  }

  Future<void> _loadWallet() async {
    final wallet = await ref.read(apiClientProvider).get(
      ApiPaths.wallet,
      parser: (data) => WalletSnapshot.fromJson(asMap(data)),
    );
    if (!mounted) {
      return;
    }
    if (wallet case Success(:final value)) {
      setState(() => _credits = creditsFromCents(value.availableBalanceCents));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProfileNotifierProvider);
    final auth = ref.watch(authNotifierProvider).user;
    final profile = state.profile;
    final name = profile?.displayName ?? auth?.displayName ?? 'Your profile';
    final phone = formatPhone(auth?.phone);

    return MistScaffold(
      body: AsyncBody(
        loading: state.status == ProfileViewStatus.loading && profile == null,
        error: state.status == ProfileViewStatus.error
            ? state.failure?.userMessage
            : null,
        onRetry: () => ref.read(myProfileNotifierProvider.notifier).load(),
        skeleton: const ScreenSkeleton.profile(),
        child: SafeArea(
          child: AppLayout.constrain(
            context,
            child: ListView(
              padding: AppLayout.pagePadding(context).copyWith(
                top: AppSpacing.md,
                bottom: AppSpacing.lg,
              ),
              children: [
                const ScreenHeader(title: 'Profile'),
                FadeInUp(
                  child: AppCard(
                    child: Column(
                      children: [
                        UserAvatar(name: name, size: 84),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.syne(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            phone,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'Edit profile',
                          variant: AppButtonVariant.ghost,
                          expanded: false,
                          onPressed: () => context.push(AppRoutes.editProfile),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeInUp(
                  delay: AppDurations.fast,
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.creditGradient,
                          ),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.onPrimary,
                        ),
                      ),
                      title: Text(
                        'Calling credits',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${_credits ?? 0} credits available',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: TextButton(
                        onPressed: () => context.go(AppRoutes.wallet),
                        child: const Text('Recharge'),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
                  child: SectionLabel('Account'),
                ),
                StaggeredList(
                  children: [
                    AppMenuTile(
                      icon: Icons.history_rounded,
                      title: 'Call history',
                      onTap: () => context.go(AppRoutes.calls),
                    ),
                    AppMenuTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      onTap: () => context.push(AppRoutes.notifications),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
                  child: SectionLabel('Settings'),
                ),
                StaggeredList(
                  children: [
                    AppMenuTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy & security',
                      onTap: () => context.push(
                        AppRoutes.legal,
                        extra: {
                          'title': 'Privacy & security',
                          'body': LegalCopy.privacy,
                        },
                      ),
                    ),
                    AppMenuTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & support',
                      onTap: () => context.push(
                        AppRoutes.legal,
                        extra: {
                          'title': 'Help & support',
                          'body': LegalCopy.contact,
                        },
                      ),
                    ),
                    AppMenuTile(
                      icon: Icons.settings_outlined,
                      title: 'App settings',
                      onTap: () => context.push(AppRoutes.settings),
                    ),
                    if (auth?.isActiveHost == true)
                      AppMenuTile(
                        icon: Icons.headset_mic_outlined,
                        title: 'Listener dashboard',
                        onTap: () => context.push(AppRoutes.hostDashboard),
                      )
                    else if (auth?.isPendingHost == true)
                      AppMenuTile(
                        icon: Icons.hourglass_top_rounded,
                        title: 'Application status',
                        onTap: () => context.push(AppRoutes.hostPending),
                      )
                    else
                      AppMenuTile(
                        icon: Icons.headset_mic_outlined,
                        title: 'Join as listener',
                        onTap: () => context.push(AppRoutes.hostApply),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AppMenuTile(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  danger: true,
                  onTap: () => ref.read(authNotifierProvider.notifier).logout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
