import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Layout + type helpers for phones, tablets, and large text accessibility.
abstract final class AppLayout {
  static const phoneMax = 600.0;
  static const tabletMax = 900.0;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isPhone(BuildContext context) => widthOf(context) < phoneMax;

  static bool isTablet(BuildContext context) {
    final w = widthOf(context);
    return w >= phoneMax && w < tabletMax;
  }

  static bool isWide(BuildContext context) => widthOf(context) >= tabletMax;

  /// Horizontal page padding that grows slightly on wide screens.
  static EdgeInsets pagePadding(BuildContext context) {
    final w = widthOf(context);
    final horizontal = w >= tabletMax
        ? 40.0
        : w >= phoneMax
        ? 28.0
        : AppSpacing.screen;
    return EdgeInsets.symmetric(horizontal: horizontal);
  }

  /// Constrains content width on tablets/desktops.
  static double contentMaxWidth(BuildContext context) {
    if (isWide(context)) return 720;
    if (isTablet(context)) return 560;
    return double.infinity;
  }

  static Widget constrain(BuildContext context, {required Widget child}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
        // Force full available width so Rows/Expanded don't shrink-wrap and overflow.
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// Clamps system text scale so layouts stay usable without freezing type size.
TextScaler appTextScaler(BuildContext context) {
  final raw = MediaQuery.textScalerOf(context).scale(1);
  final clamped = raw.clamp(0.85, 1.35);
  return TextScaler.linear(clamped);
}

/// Prefer this for hero titles so large accessibility text wraps cleanly.
class AdaptiveTitle extends StatelessWidget {
  const AdaptiveTitle(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 3,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final base = style ?? theme.titleLarge;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(0.9, 1.12);
    final size = math.min((base?.fontSize ?? 24) * scale, 30.0);
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
      style: GoogleFonts.figtree(
        fontSize: size,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: base?.color ?? AppColors.textPrimary,
      ),
    );
  }
}
