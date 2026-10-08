import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../motion/app_motion.dart';

/// Compact status pill used across production lists.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusBadgeTone.neutral,
  });

  final String label;
  final StatusBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusBadgeTone.success => (AppColors.successSoft, AppColors.success),
      StatusBadgeTone.danger => (AppColors.dangerSoft, AppColors.danger),
      StatusBadgeTone.warning => (AppColors.warningSoft, AppColors.warning),
      StatusBadgeTone.brand => (
        AppColors.primary.withValues(alpha: 0.12),
        AppColors.primaryDim,
      ),
      StatusBadgeTone.neutral => (AppColors.surfaceMuted, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.figtree(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

enum StatusBadgeTone { neutral, success, danger, warning, brand }

/// Dense list row used for calls, chats, transactions.
class EnterpriseListTile extends StatelessWidget {
  const EnterpriseListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dense = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: AppColors.surfaceElevated,
      elevation: 1,
      shadowColor: AppColors.softShadow,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: dense ? 12 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.figtree(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.figtree(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
    return tile;
  }
}

/// Production empty state with optional primary action.
class EnterpriseEmptyState extends StatelessWidget {
  const EnterpriseEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                color: AppColors.textSecondary,
                height: 1.4,
                fontSize: 14,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MetricChip extends StatelessWidget {
  const MetricChip({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.figtree(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
