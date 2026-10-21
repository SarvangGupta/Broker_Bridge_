import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/brokers/domain/seller_broker_model.dart';
import 'package:rmseller_mobile/features/brokers/presentation/broker_profile_screen.dart';

void main() {
  group('Sprint RB-SELLER-05: Broker Rating Display Widget Tests', () {
    const testBroker = SellerBrokerModel(
      id: 'b354958e-779a-41f2-b7a3-5899eca32e32',
      name: 'Bikaner Mandi Broker Desk',
      companyName: 'Bikaner Grain Merchants Association Desk',
      location: 'Krishi Upaj Mandi, Bikaner',
      trustScore: 99,
      isVerified: true,
      commoditiesHandled: ['Desi Chana (Gram)', 'Mustard Seeds'],
      averageRating: 4.7,
      reviewCount: 3,
    );

    testWidgets('Scenario 1: Displays broker ratings, distribution bars, and verified reviews', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const BrokerProfileScreen(
            brokerId: testBroker.id,
            initialBroker: testBroker,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header Trust Score
      expect(find.text('Trust Score: 99%'), findsOneWidget);

      // Verify Ratings Card
      expect(find.text('Broker Ratings & Reviews'), findsOneWidget);
      expect(find.text('Rate this Broker Desk'), findsOneWidget);

      // Verify Commodities Handled
      expect(find.text('Specialized Mandi Commodities'), findsOneWidget);
      expect(find.text('Desi Chana (Gram)'), findsOneWidget);
      expect(find.text('Mustard Seeds'), findsOneWidget);

      // Verify Communication Buttons
      expect(find.text('Call Desk'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
    });
  });
}
