import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Light and dark themes. Screens read colours and text styles from here
/// through `Theme.of(context)` rather than setting their own.
abstract final class AppTheme {
  static final light = _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.ink,
      onPrimary: AppColors.white,
      secondary: AppColors.mint,
      onSecondary: AppColors.ink,
      error: AppColors.lightError,
      onError: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.lightMutedText,
      outline: AppColors.lightBorder,
    ),
    background: AppColors.lightBackground,
  );

  static final dark = _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.mint,
      onPrimary: AppColors.ink,
      secondary: AppColors.mint,
      onSecondary: AppColors.ink,
      error: AppColors.darkError,
      onError: AppColors.ink,
      surface: AppColors.darkSurface,
      onSurface: AppColors.white,
      onSurfaceVariant: AppColors.darkMutedText,
      outline: AppColors.darkBorder,
    ),
    background: AppColors.darkBackground,
  );

  static ThemeData _build(ColorScheme colors, {required Color background}) {
    return ThemeData(
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: colors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
    );
  }
}
