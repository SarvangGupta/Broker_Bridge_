import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/offers/data/offers_repository.dart';
import 'package:rmbuyer_mobile/features/offers/presentation/buyer_offers_screen.dart';

void main() {
  setUp(() {
    OffersRepository.resetForTesting();
  });

  Widget buildTestWidget({String? requirementId, OffersRepository? repo}) {
    return MaterialApp(
      home: BuyerOffersScreen(
        initialRequirementId: requirementId,
        repository: repo,
      ),
    );
  }

  group('RB-BUYER-05: BuyerOffersScreen Widget Tests', () {
    testWidgets('Renders offers screen title, Counterparty Shield banner, and offer cards', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Title & Shield
      expect(find.text('Broker Offers & Proposals'), findsOneWidget);
      expect(find.textContaining('Counterparty Shield'), findsOneWidget);

      // Offer details
      expect(find.text('Yellow Maize (Corn)'), findsWidgets);
      expect(find.textContaining('Kota Agro Warehousing Broker Desk'), findsWidgets);

      // Review CTA
      expect(find.text('Review & Negotiate'), findsWidgets);
    });

    testWidgets('Status filter chips filter the offers list', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on 'Accepted' filter chip
      final acceptedChip = find.text('Accepted');
      expect(acceptedChip, findsOneWidget);
      await tester.tap(acceptedChip);
      await tester.pumpAndSettle();

      // Only Accepted offers should be visible
      expect(find.text('ACCEPTED'), findsOneWidget);
      expect(find.text('PROPOSED'), findsNothing);
    });
  });
}
