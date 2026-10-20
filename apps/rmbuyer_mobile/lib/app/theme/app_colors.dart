import 'package:flutter/material.dart';

/// Design tokens for RMBuyer Enterprise mobile client.
/// Adheres to the approved RB-BUYER palette:
/// - Forest green: #173B32 (Primary brand)
/// - Amber: #E99A32 (Accent & Call-to-action)
/// - Off-white: #F6F8F7 (Light background)
/// - Charcoal: #263238 (Dark surface & primary text)
class AppColors {
  const AppColors._();

  // Primary Brand: Forest Green
  static const Color primary = Color(0xFF173B32);
  static const Color primaryLight = Color(0xFF245549);
  static const Color primaryDark = Color(0xFF0F2620);
  static const Color primaryContainer = Color(0xFFE2ECE9);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary & Accents: Amber
  static const Color secondary = Color(0xFFE99A32);
  static const Color secondaryLight = Color(0xFFF3B765);
  static const Color secondaryDark = Color(0xFFB57016);
  static const Color secondaryContainer = Color(0xFFFDF2E2);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Neutral Palette: Off-white & Charcoal
  static const Color backgroundLight = Color(0xFFF6F8F7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF263238);
  static const Color textSecondaryLight = Color(0xFF546E7A);
  static const Color textMutedLight = Color(0xFF90A4AE);

  // Dark Palette
  static const Color backgroundDark = Color(0xFF1A2327);
  static const Color surfaceDark = Color(0xFF263238);
  static const Color cardDark = Color(0xFF1E282D);
  static const Color borderDark = Color(0xFF37474F);
  static const Color textPrimaryDark = Color(0xFFF6F8F7);
  static const Color textSecondaryDark = Color(0xFFCFD8DC);
  static const Color textMutedDark = Color(0xFF90A4AE);

  // Semantic States
  static const Color success = Color(0xFF059669);
  static const Color successBackground = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBackground = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBackground = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0284C7);
  static const Color infoBackground = Color(0xFFE0F2FE);

  // Convenience Aliases
  static const Color charcoal = Color(0xFF263238);
  static const Color offWhite = Color(0xFFF6F8F7);
  static const Color forestGreen = Color(0xFF173B32);
  static const Color amber = Color(0xFFE99A32);
  static const Color textPrimary = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;
  static const Color textMuted = textMutedLight;
}
