import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_colors.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';

void main() {
  group('RMBuyer Design System & Color Tokens Tests', () {
    test('AppColors matches the approved specification', () {
      // Forest green: #173B32
      expect(AppColors.primary, const Color(0xFF173B32));
      // Amber: #E99A32
      expect(AppColors.secondary, const Color(0xFFE99A32));
      // Off-white: #F6F8F7
      expect(AppColors.backgroundLight, const Color(0xFFF6F8F7));
      // Charcoal: #263238
      expect(AppColors.textPrimaryLight, const Color(0xFF263238));
    });

    test('AppTheme creates lightTheme without errors', () {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.secondary, AppColors.secondary);
      expect(theme.scaffoldBackgroundColor, AppColors.backgroundLight);
    });
  });
}
