import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final display = GoogleFonts.plusJakartaSansTextTheme();
    final body = GoogleFonts.plusJakartaSansTextTheme();
    final textTheme = body.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        height: 1.05,
      ),
      displayMedium: display.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.1,
      ),
      displaySmall: display.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineLarge: display.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: display.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: body.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: body.bodyMedium?.copyWith(height: 1.45),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.accent,
        onSecondary: AppColors.onAccent,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
        outline: AppColors.border,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const Icon(Icons.arrow_back_ios),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background.withValues(alpha: 0.92),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        elevation: 0,
        height: 72,
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.textMuted,
            size: 24,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceElevated,
        disabledColor: AppColors.surfaceMuted,
        labelStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Finite min width — Size.fromHeight uses infinity and breaks Buttons in Rows.
          minimumSize: const Size(64, 54),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.border,
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDim,
          side: const BorderSide(color: AppColors.borderStrong),
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryDim),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.backgroundDeep,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.onDeep,
          height: 1.35,
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }
}
