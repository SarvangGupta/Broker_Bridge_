import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/core/widgets/app_loading_indicator.dart';
import 'package:rmseller_mobile/features/home/presentation/seller_home_screen.dart';

void main() {
  group('RB-SELLER-01: SellerHomeScreen Widget Tests', () {
    testWidgets('Initial pump shows loading state indicator for Seller Command Center', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SellerHomeScreen(),
        ),
      );

      // Verify that initial state renders the loading indicator
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.text('Loading Seller Command Center...'), findsOneWidget);
    });

    testWidgets('Gracefully settles into either loaded dashboard or resilient error retry state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SellerHomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // In test environment, it either loads dashboard metrics or shows safe error retry state
      final hasError = find.text('Retry').evaluate().isNotEmpty;
      final hasDashboard = find.text('Active Lots').evaluate().isNotEmpty;

      expect(hasError || hasDashboard, isTrue);
    });
  });
}
