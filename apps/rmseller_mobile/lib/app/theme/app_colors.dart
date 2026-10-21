import 'package:flutter/material.dart';

/// Design tokens for RMSeller Enterprise mobile client.
/// Adheres to the approved Seller palette:
/// - Deep Burgundy: #7C1D24 (Primary brand, commodity & grain production)
/// - Amber Gold: #D97706 (Accent & Call-to-action)
/// - Off-white / Ivory: #FBFBF9 (Light background)
/// - Slate Charcoal: #1E293B (Dark surface & primary text)
class AppColors {
  const AppColors._();

  // Primary Brand: Deep Burgundy
  static const Color primary = Color(0xFF7C1D24);
  static const Color primaryLight = Color(0xFFA32832);
  static const Color primaryDark = Color(0xFF561318);
  static const Color primaryContainer = Color(0xFFF9EBEB);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary & Accents: Amber Gold
  static const Color secondary = Color(0xFFD97706);
  static const Color secondaryLight = Color(0xFFF59E0B);
  static const Color secondaryDark = Color(0xFFB45309);
  static const Color secondaryContainer = Color(0xFFFEF3C7);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Neutral Palette: Off-white & Slate Charcoal
  static const Color backgroundLight = Color(0xFFFBFBF9);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF1E293B);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // Dark Palette
  static const Color backgroundDark = Color(0xFF111827);
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color cardDark = Color(0xFF182234);
  static const Color borderDark = Color(0xFF374151);
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFFD1D5DB);
  static const Color textMutedDark = Color(0xFF9CA3AF);

  // Semantic States
  static const Color success = Color(0xFF059669);
  static const Color successBackground = Color(0xFFD1FAE5);
  static const Color successContainer = successBackground;
  static const Color warning = Color(0xFFD97706);
  static const Color warningBackground = Color(0xFFFEF3C7);
  static const Color warningContainer = warningBackground;
  static const Color error = Color(0xFFDC2626);
  static const Color errorBackground = Color(0xFFFEE2E2);
  static const Color errorContainer = errorBackground;
  static const Color info = Color(0xFF0284C7);
  static const Color infoBackground = Color(0xFFE0F2FE);
  static const Color infoContainer = infoBackground;

  // Convenience Aliases
  static const Color burgundy = Color(0xFF7C1D24);
  static const Color amber = Color(0xFFD97706);
  static const Color textPrimary = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;
  static const Color textMuted = textMutedLight;
}
