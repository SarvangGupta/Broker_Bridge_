import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_colors.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';

void main() {
  group('RB-SELLER-01: AppTheme & Design Token Tests', () {
    test('Primary color adheres to approved Burgundy brand', () {
      expect(AppColors.primary, const Color(0xFF7C1D24));
      expect(AppColors.secondary, const Color(0xFFD97706));
    });

    test('ThemeData builds valid Material 3 light theme with consistent color scheme', () {
      final theme = AppTheme.lightTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.secondary, AppColors.secondary);
      expect(theme.scaffoldBackgroundColor, AppColors.backgroundLight);
    });

    test('ThemeData builds valid Material 3 dark theme', () {
      final theme = AppTheme.darkTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
    });
  });
}
