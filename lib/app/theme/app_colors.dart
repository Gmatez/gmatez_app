import 'package:flutter/material.dart';

/// Gmatez blue, matched to the product logo.
abstract final class AppColors {
  // Atmosphere
  static const background = Color(0xFFF5F7FF);
  static const backgroundDeep = Color(0xFF141A66);
  static const mist = Color(0xFFEEF0FF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFE8ECFF);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const border = Color(0xFFD9E0FF);
  static const borderStrong = Color(0xFFB7C2FF);

  // Brand
  static const primary = Color(0xFF3D4FFF);
  static const primaryDim = Color(0xFF2C3AE0);
  static const primarySoft = Color(0xFF6D7CFF);
  static const accent = Color(0xFF7C8CFF);
  static const accentDim = Color(0xFF2430B8);
  static const tideGlow = Color(0xFFC7D0FF);

  // Semantic
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFDCFCE7);
  static const danger = Color(0xFFE11D48);
  static const dangerSoft = Color(0xFFFFE4E6);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFEF3C7);

  // Text
  static const textPrimary = Color(0xFF12163A);
  static const textSecondary = Color(0xFF5C648A);
  static const textMuted = Color(0xFF8B93B3);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onDeep = Color(0xFFF8F6FF);
  static const onAccent = Color(0xFFFFFFFF);

  /// Distinct from brand purple — warm rose shimmer for loading skeletons.
  static const skeletonBase = Color(0xFFE8ECFF);
  static const skeletonHighlight = Color(0xFFF8F9FF);
  static const skeletonMid = Color(0xFFDDE3FF);

  static const introGradient = [
    Color(0xFF141A66),
    Color(0xFF2430B8),
    Color(0xFF3D4FFF),
    Color(0xFF6D7CFF),
  ];

  static const creditGradient = [
    Color(0xFF2430B8),
    Color(0xFF3D4FFF),
    Color(0xFF6D7CFF),
  ];

  static const heroWash = [
    Color(0xFFF5F7FF),
    Color(0xFFEEF0FF),
    Color(0xFFE4E9FF),
  ];

  static const cardShadow = Color(0x1A141A66);
  static const softShadow = Color(0x143D4FFF);
}
