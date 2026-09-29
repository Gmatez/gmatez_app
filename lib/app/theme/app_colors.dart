import 'package:flutter/material.dart';

/// Gmatez purple product language (Listener mockups).
abstract final class AppColors {
  // Atmosphere
  static const background = Color(0xFFF4F1FF);
  static const backgroundDeep = Color(0xFF2A1570);
  static const mist = Color(0xFFEDE8FF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEEE9FF);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4DDF8);
  static const borderStrong = Color(0xFFC9BFF0);

  // Brand
  static const primary = Color(0xFF6D4AFF);
  static const primaryDim = Color(0xFF5536E0);
  static const primarySoft = Color(0xFF8B6CFF);
  static const accent = Color(0xFFC084FC);
  static const accentDim = Color(0xFFA855F7);
  static const tideGlow = Color(0xFFD8B4FE);

  // Semantic
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFDCFCE7);
  static const danger = Color(0xFFE11D48);
  static const dangerSoft = Color(0xFFFFE4E6);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFEF3C7);

  // Text
  static const textPrimary = Color(0xFF1A1240);
  static const textSecondary = Color(0xFF6B628C);
  static const textMuted = Color(0xFF9A92B5);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onDeep = Color(0xFFF8F6FF);
  static const onAccent = Color(0xFFFFFFFF);

  /// Distinct from brand purple — warm rose shimmer for loading skeletons.
  static const skeletonBase = Color(0xFFF3E8FF);
  static const skeletonHighlight = Color(0xFFFFF1F2);
  static const skeletonMid = Color(0xFFFCE7F3);

  static const introGradient = [
    Color(0xFF2A1570),
    Color(0xFF3B1D9E),
    Color(0xFF6D4AFF),
    Color(0xFF8B6CFF),
  ];

  static const creditGradient = [
    Color(0xFF5536E0),
    Color(0xFF6D4AFF),
    Color(0xFF8B6CFF),
  ];

  static const heroWash = [
    Color(0xFFF4F1FF),
    Color(0xFFEDE8FF),
    Color(0xFFE4DDF8),
  ];

  static const cardShadow = Color(0x1A2A1570);
  static const softShadow = Color(0x146D4AFF);
}
