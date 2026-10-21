import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/ratings/data/seller_ratings_repository.dart';
import 'package:rmseller_mobile/features/ratings/presentation/rate_broker_screen.dart';

void main() {
  group('Sprint RB-SELLER-05: RateBrokerScreen Widget Tests', () {
    late SellerRatingsRepository repository;

    setUp(() {
      SellerRatingsRepository.resetCacheForTesting();
      repository = SellerRatingsRepository();
    });

    testWidgets('Scenario 1: Renders rating form with stars, criteria, and Counterparty Shield', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RateBrokerScreen(
            brokerId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
            brokerName: 'Bikaner Mandi Broker Desk',
            dealId: 'd354958e-779a-41f2-b7a3-5899eca32e01',
            dealReference: 'BKG-2026-0881',
            repository: repository,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header verification
      expect(find.text('Bikaner Mandi Broker Desk'), findsOneWidget);
      expect(find.text('Verified Trade: BKG-2026-0881'), findsOneWidget);

      // Star rating section
      expect(find.text('Overall Desk Rating'), findsOneWidget);
      expect(find.byType(IconButton), findsWidgets);

      // Criteria section
      expect(find.text('Detailed Trading Criteria'), findsOneWidget);
      expect(find.text('Mandi Rate Discovery & Market Knowledge'), findsOneWidget);
      expect(find.text('Promptness & Loading Coordination'), findsOneWidget);
      expect(find.text('Payment & Settlement Timeliness'), findsOneWidget);
      expect(find.text('Communication & Term Transparency'), findsOneWidget);

      // Feedback input
      expect(find.text('Written Feedback & Suggestions'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Shield notice
      expect(find.textContaining('Counterparty Shield: Direct buyer contact'), findsOneWidget);

      // Submit Button
      expect(find.text('Submit Broker Rating'), findsOneWidget);
    });

    testWidgets('Scenario 2: Tapping submit opens review confirmation dialog before submission', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RateBrokerScreen(
            brokerId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
            brokerName: 'Bikaner Mandi Broker Desk',
            dealId: 'd354958e-779a-41f2-b7a3-5899eca32e01',
            dealReference: 'BKG-2026-0881',
            repository: repository,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter feedback
      await tester.enterText(find.byType(TextField), 'Smooth Mandi lot clearance and prompt weighing slips.');
      await tester.pump();

      // Tap submit button
      await tester.tap(find.text('Submit Broker Rating'));
      await tester.pumpAndSettle();

      // Confirmation dialog should be displayed
      expect(find.text('Confirm Broker Rating'), findsOneWidget);
      expect(find.text('Broker Desk: Bikaner Mandi Broker Desk'), findsOneWidget);
      expect(find.text('Linked Trade: BKG-2026-0881'), findsOneWidget);
      expect(find.text('Overall Rating'), findsOneWidget);
      expect(find.text('Submit Rating'), findsOneWidget);
      expect(find.text('Edit Details'), findsOneWidget);
    });
  });
}
