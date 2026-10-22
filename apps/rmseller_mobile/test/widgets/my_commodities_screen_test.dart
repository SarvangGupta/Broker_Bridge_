import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/commodities/presentation/my_commodities_screen.dart';

void main() {
  group('RB-SELLER-01: MyCommoditiesScreen Widget Tests', () {
    testWidgets('Renders app bar title and Post Commodity action button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MyCommoditiesScreen(),
        ),
      );

      expect(find.text('My Commodities'), findsOneWidget);
      expect(find.text('Post Commodity'), findsOneWidget);
      expect(find.byIcon(LucideIcons.plus), findsAtLeastNWidgets(1));
    });

    testWidgets('Renders status filter chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MyCommoditiesScreen(),
        ),
      );

      expect(find.text('All Supply'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Reserved'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
    });
  });
}
