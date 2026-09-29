import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_layout.dart';
import '../../app/theme/app_tokens.dart';
import '../motion/app_motion.dart';
import 'skeletons.dart';

export 'skeletons.dart';

enum AppButtonVariant { primary, secondary, ghost, danger, accent }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.variant = AppButtonVariant.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final AppButtonVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: variant == AppButtonVariant.ghost
                  ? AppColors.primary
                  : AppColors.onPrimary,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final enabled = loading ? null : onPressed;
    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: enabled,
        child: child,
      ),
      AppButtonVariant.accent => FilledButton(
        onPressed: enabled,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
        ),
        child: child,
      ),
      AppButtonVariant.secondary => FilledButton(
        onPressed: enabled,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surfaceMuted,
          foregroundColor: AppColors.primaryDim,
        ),
        child: child,
      ),
      AppButtonVariant.ghost => OutlinedButton(
        onPressed: enabled,
        child: child,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: enabled,
        style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
        child: child,
      ),
    };

    if (!expanded) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.readOnly = false,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool readOnly;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.bordered = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: AppDurations.fast,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: bordered
            ? Border.all(color: AppColors.border)
            : null,
        boxShadow: const [
          BoxShadow(
            color: AppColors.softShadow,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) {
      return content;
    }
    return PressableScale(
      onTap: onTap,
      child: content,
    );
  }
}

class AppMenuTile extends StatelessWidget {
  const AppMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (danger ? AppColors.danger : AppColors.primary).withValues(
              alpha: 0.12,
            ),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(
            icon,
            color: danger ? AppColors.danger : AppColors.primary,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: danger ? AppColors.danger : AppColors.textMuted,
        ),
      ),
    );
  }
}

class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.loading,
    required this.child,
    this.error,
    this.onRetry,
    this.empty = false,
    this.emptyMessage = 'Nothing to show yet.',
    this.emptyIcon = Icons.inbox_outlined,
    this.skeleton,
    this.animateChild = true,
  });

  final bool loading;
  final Widget child;
  final String? error;
  final VoidCallback? onRetry;
  final bool empty;
  final String emptyMessage;
  final IconData emptyIcon;
  /// Optional custom skeleton. Defaults to a staggered list skeleton.
  final Widget? skeleton;
  /// Soft entrance when content replaces the skeleton.
  final bool animateChild;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return skeleton ?? const ScreenSkeleton.list();
    }
    if (error != null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Something went wrong',
        message: error!,
        actionLabel: onRetry == null ? null : 'Try again',
        onAction: onRetry,
      );
    }
    if (empty) {
      return EmptyState(
        icon: emptyIcon,
        title: 'All quiet here',
        message: emptyMessage,
      );
    }
    if (!animateChild) {
      return child;
    }
    return FadeInUp(
      duration: AppDurations.fast,
      child: child,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: FadeInUp(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(icon, size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expanded: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppLayout.pagePadding(context).left,
        AppSpacing.md,
        AppLayout.pagePadding(context).right,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdaptiveTitle(title),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}

class SoftChip extends StatelessWidget {
  const SoftChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      labelStyle: TextStyle(
        color: selected ? AppColors.onPrimary : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      onSelected: onSelected,
    );
  }
}

class GradientBackdrop extends StatelessWidget {
  const GradientBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.introGradient,
          ),
        ),
        child: child,
      ),
    );
  }
}

class MistScaffold extends StatelessWidget {
  const MistScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extendBodyBehindAppBar = false,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.heroWash,
          ),
        ),
        child: body,
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.figtree(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
