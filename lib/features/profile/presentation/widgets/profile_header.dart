import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/user_profile.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        UserAvatar(
          name: profile.displayName,
          imageUrl: profile.avatarUrl,
          size: 96,
          online: profile.online,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          profile.displayName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.syne(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: profile.availableForCall
                ? AppColors.successSoft
                : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            profile.availableForCall
                ? 'Available for calls'
                : profile.online
                ? 'Online'
                : 'Offline',
            style: TextStyle(
              color: profile.availableForCall
                  ? AppColors.success
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileDetails extends StatelessWidget {
  const ProfileDetails({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile.bio.isNotEmpty) ...[
          const SectionLabel('Bio'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            profile.bio,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        const SectionLabel('Details'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (profile.language != null)
              _Chip(label: 'Language ${profile.language}'),
            ...profile.languages.map((value) => _Chip(label: value)),
            ...profile.interests.map((value) => _Chip(label: value)),
            if (profile.country != null) _Chip(label: profile.country!),
            _Chip(label: profile.rateLabel),
            if (profile.videoRatePerMinuteCents != null)
              _Chip(label: profile.videoRateLabel),
            _Chip(label: profile.gender.toLowerCase()),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDim,
        ),
      ),
    );
  }
}
