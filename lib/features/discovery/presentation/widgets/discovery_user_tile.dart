import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/enterprise_widgets.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../../calls/presentation/state/active_call_notifier.dart';
import '../../../calls/presentation/state/call_rate_provider.dart';
import '../../../profile/domain/entities/user_profile.dart';

class DiscoveryUserTile extends ConsumerWidget {
  const DiscoveryUserTile({super.key, required this.user, required this.onTap});

  final UserProfile user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = user.online || user.availableForCall;
    final rateCents = displayRateCents(
      user.ratePerMinuteCents,
      ref.watch(userCallRateProvider).value,
    );
    final rate = '${(rateCents / 10).round()} cr/min';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                name: user.displayName,
                imageUrl: user.avatarUrl,
                online: online,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.figtree(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        StatusBadge(
                          label: online ? 'Online' : 'Away',
                          tone: online
                              ? StatusBadgeTone.success
                              : StatusBadgeTone.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.bio.isEmpty ? 'Professional listener · Ready now' : user.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.figtree(
                        color: AppColors.textSecondary,
                        height: 1.35,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          label: user.languages.isNotEmpty
                              ? user.languages.take(2).join(', ')
                              : (user.language ?? 'Any language'),
                        ),
                        _MetaChip(label: rate),
                        if (user.videoEnabled) const _MetaChip(label: 'Video'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Voice',
                  icon: Icons.call_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: user.availableForCall && user.voiceEnabled
                      ? () => _call(context, ref, 'VOICE')
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Video',
                  icon: Icons.videocam_rounded,
                  onPressed: user.availableForCall && user.videoEnabled
                      ? () => _call(context, ref, 'VIDEO')
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _call(
    BuildContext context,
    WidgetRef ref,
    String callType,
  ) async {
    final result = await ref
        .read(activeCallProvider.notifier)
        .startCall(calleeId: user.userId, callType: callType);
    if (!context.mounted) {
      return;
    }
    switch (result) {
      case Success(:final value):
        await context.push(AppRoutes.callFor(value.id));
      case Failure(:final failure):
        final goWallet =
            failure.code == 'WALLET_INSUFFICIENT_FUNDS' ||
            failure.code == 'INSUFFICIENT_BALANCE';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.userMessage),
            action: goWallet &&
                    ref.read(authNotifierProvider).user?.isActiveHost != true
                ? SnackBarAction(
                    label: 'Top up',
                    onPressed: () => context.push(AppRoutes.wallet),
                  )
                : null,
          ),
        );
    }
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.figtree(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDim,
        ),
      ),
    );
  }
}

class DiscoverySkeleton extends StatelessWidget {
  const DiscoverySkeleton({super.key, this.padding = AppSpacing.md});

  final double padding;

  @override
  Widget build(BuildContext context) {
    return ScreenSkeleton.feed(
      padding: EdgeInsets.all(padding),
    );
  }
}
