import 'package:flutter/material.dart';

/// Design tokens for RMBroker Enterprise mobile client.
class AppColors {
  const AppColors._();

  // Primary Brand: Deep Teal & Emerald
  static const Color primary = Color(0xFF0F766E); // Teal 700
  static const Color primaryLight = Color(0xFF14B8A6); // Teal 500
  static const Color primaryDark = Color(0xFF115E59); // Teal 800
  static const Color primaryContainer = Color(0xFFCCFBF1); // Teal 100

  // Secondary & Accents
  static const Color secondary = Color(0xFF0284C7); // Sky 600
  static const Color secondaryContainer = Color(0xFFE0F2FE); // Sky 100
  static const Color accent = Color(0xFF10B981); // Emerald 500

  // Semantic States
  static const Color success = Color(0xFF059669); // Green 600
  static const Color successBackground = Color(0xFFD1FAE5); // Green 100
  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color warningBackground = Color(0xFFFEF3C7); // Amber 100
  static const Color error = Color(0xFFDC2626); // Red 600
  static const Color errorBackground = Color(0xFFFEE2E2); // Red 100
  static const Color info = Color(0xFF2563EB); // Blue 600
  static const Color infoBackground = Color(0xFFDBEAFE); // Blue 100

  // Light Palette Neutrals
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF); // White
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF475569); // Slate 600
  static const Color textMutedLight = Color(0xFF94A3B8); // Slate 400

  // Dark Palette Neutrals
  static const Color backgroundDark = Color(0xFF090D16);
  static const Color surfaceDark = Color(0xFF111827); // Gray 900
  static const Color cardDark = Color(0xFF182234);
  static const Color borderDark = Color(0xFF1E293B); // Slate 800
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color textMutedDark = Color(0xFF64748B); // Slate 500

  // Convenience Aliases for Design System
  static const Color primaryNavy = Color(0xFF0F172A); // Slate 900
  static const Color textPrimary = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;
  static const Color textDisabled = textMutedLight;
  static const Color surfaceVariantLight = Color(0xFFF1F5F9); // Slate 100
  static const Color goldMuted = Color(0xFFFDE68A); // Amber 200
  static const Color goldDark = Color(0xFFB45309); // Amber 700
}
