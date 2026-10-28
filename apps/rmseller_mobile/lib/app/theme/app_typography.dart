import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale for RMSeller Mobile Enterprise client.
/// Configured with Devanagari Unicode font fallback support for Indian languages.
class AppTypography {
  const AppTypography._();

  static const List<String> devanagariFontFallback = [
    'Noto Sans Devanagari',
    'NotoSansDevanagari',
    'sans-serif',
  ];

  static const TextStyle displayLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimaryLight,
    fontFamilyFallback: devanagariFontFallback,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimaryLight,
    fontFamilyFallback: devanagariFontFallback,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimaryLight,
    fontFamilyFallback: devanagariFontFallback,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    fontFamilyFallback: devanagariFontFallback,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    fontFamilyFallback: devanagariFontFallback,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimaryLight,
    fontFamilyFallback: devanagariFontFallback,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimaryLight,
    fontFamilyFallback: devanagariFontFallback,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryLight,
    fontFamilyFallback: devanagariFontFallback,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    fontFamilyFallback: devanagariFontFallback,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamilyFallback: devanagariFontFallback,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    fontFamilyFallback: devanagariFontFallback,
  );
}
