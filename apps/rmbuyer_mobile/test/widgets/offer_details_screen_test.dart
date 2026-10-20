import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/offers/data/offers_repository.dart';
import 'package:rmbuyer_mobile/features/offers/presentation/offer_details_screen.dart';

void main() {
  setUp(() {
    OffersRepository.resetForTesting();
  });

  Widget buildTestWidget({required String offerId, OffersRepository? repo}) {
    return MaterialApp(
      home: OfferDetailsScreen(
        offerId: offerId,
        repository: repo,
      ),
    );
  }

  group('RB-BUYER-05: OfferDetailsScreen Widget Tests', () {
    testWidgets('Renders commercial overview, delivery terms, and negotiation rounds ledger', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'OFFER-2026-081'));
      await tester.pumpAndSettle();

      // Header & details
      expect(find.text('Yellow Maize (Corn)'), findsWidgets);
      expect(find.text('PROPOSED'), findsWidgets);
      expect(find.text('Offered Rate'), findsOneWidget);
      expect(find.textContaining('Kota Agro Warehousing Broker Desk'), findsWidgets);

      // Charges breakdown
      expect(find.text('Brokerage & Facilitation Fee'), findsOneWidget);

      // Delivery terms
      expect(find.text('Delivery Destination'), findsOneWidget);
      expect(find.textContaining('Kota Industrial Area Mill Hub'), findsWidgets);

      // Rounds ledger
      expect(find.textContaining('Negotiation History & Rounds Ledger'), findsOneWidget);
      expect(find.textContaining('Round 1:'), findsOneWidget);
      expect(find.textContaining('Round 2:'), findsOneWidget);

      // Action buttons
      expect(find.text('Counter-Offer'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('Tapping Counter-Offer opens bottom sheet and successfully submits new round', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'OFFER-2026-081'));
      await tester.pumpAndSettle();

      final counterBtn = find.text('Counter-Offer');
      expect(counterBtn, findsOneWidget);
      await tester.tap(counterBtn);
      await tester.pumpAndSettle();

      // Modal is open
      expect(find.text('Submit Counter-Offer'), findsOneWidget);
      expect(find.text('Confirm & Submit to Broker'), findsOneWidget);

      // Tap submit
      await tester.tap(find.text('Confirm & Submit to Broker'));
      await tester.pumpAndSettle();

      // Check that status is now Countered and Round 3 is appended
      expect(find.text('COUNTERED'), findsWidgets);
      expect(find.textContaining('Round 3:'), findsOneWidget);
    });

    testWidgets('Tapping Accept opens confirmation dialog and updates status to Accepted', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'OFFER-2026-081'));
      await tester.pumpAndSettle();

      final acceptBtn = find.text('Accept');
      expect(acceptBtn, findsOneWidget);
      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Accept Offer Terms'), findsOneWidget);
      expect(find.text('Confirm Acceptance'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Confirm Acceptance'));
      await tester.pumpAndSettle();

      // Check status updated to Accepted
      expect(find.text('ACCEPTED'), findsWidgets);
      expect(find.textContaining('Proposal Accepted. Broker desk preparing final trade deal.'), findsOneWidget);
    });

    testWidgets('Tapping Reject opens reason dialog and updates status to Rejected', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'OFFER-2026-081'));
      await tester.pumpAndSettle();

      final rejectBtn = find.text('Reject');
      expect(rejectBtn, findsOneWidget);
      await tester.tap(rejectBtn);
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Reject Offer'), findsOneWidget);
      expect(find.text('Confirm Rejection'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Confirm Rejection'));
      await tester.pumpAndSettle();

      // Check status updated to Rejected
      expect(find.text('REJECTED'), findsWidgets);
      expect(find.textContaining('Proposal Rejected. No further actions permitted on this offer.'), findsOneWidget);
    });

    testWidgets('Expired offers render expired banner and do not show action buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'OFFER-2026-084'));
      await tester.pumpAndSettle();

      expect(find.text('EXPIRED'), findsWidgets);
      expect(find.textContaining('Offer Validity Expired'), findsOneWidget);
      expect(find.text('Counter-Offer'), findsNothing);
      expect(find.text('Accept'), findsNothing);
    });
  });
}
