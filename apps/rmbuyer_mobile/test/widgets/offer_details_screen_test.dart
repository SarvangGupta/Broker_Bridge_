import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/offers/data/offers_repository.dart';
import 'package:rmbuyer_mobile/features/offers/domain/buyer_offer_model.dart';
import 'package:rmbuyer_mobile/features/offers/presentation/offer_details_screen.dart';

class ThrowingOffersRepository extends OffersRepository {
  @override
  Future<BuyerOffer?> getOfferById(String id) async {
    throw Exception('Simulated network failure connecting to broker API');
  }
}

void main() {
  setUp(() {
    OffersRepository.resetForTesting();
  });

  Widget buildTestWidget({
    required String offerId,
    BuyerOffer? initialOffer,
    OffersRepository? repo,
  }) {
    return MaterialApp(
      home: OfferDetailsScreen(
        offerId: offerId,
        initialOffer: initialOffer,
        repository: repo,
      ),
    );
  }

  group('MICRO-SPRINT: RMBUYER-PROPOSAL-DETAIL-BLANK-01 Tests', () {
    testWidgets('View 3: Renders loaded commercial details tab, metrics grid, and 3-button action bar', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'OFFER-2026-081'));
      await tester.pumpAndSettle();

      // App bar & commodity overview
      expect(find.text('Yellow Maize (Corn)'), findsWidgets);
      expect(find.text('PROPOSED'), findsWidgets);
      expect(find.text('View Requirement'), findsOneWidget);

      // Tabs
      expect(find.byKey(const Key('tab-details')), findsOneWidget);
      expect(find.byKey(const Key('tab-history')), findsOneWidget);
      expect(find.byKey(const Key('tab-documents')), findsOneWidget);

      // 2x2 metric grid
      expect(find.text('Offered Rate'), findsOneWidget);
      expect(find.text('Offered Quantity'), findsOneWidget);
      expect(find.text('Total Value'), findsOneWidget);
      expect(find.text('Delivery Location'), findsOneWidget);
      expect(find.textContaining('100'), findsWidgets);

      // Terms & Broker Desk info
      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.text('Broker Message'), findsOneWidget);
      expect(find.textContaining('Kota Agro Warehousing Broker Desk'), findsWidgets);

      // Bottom persistent 3-button action bar
      expect(find.byKey(const Key('offer-make-counter-btn')), findsOneWidget);
      expect(find.byKey(const Key('offer-accept-btn')), findsOneWidget);
      expect(find.byKey(const Key('offer-decline-btn')), findsOneWidget);
      expect(find.text('Make Counter Offer'), findsOneWidget);
      expect(find.text('Accept Offer'), findsOneWidget);
      expect(find.text('Decline Offer'), findsOneWidget);
    });

    testWidgets('View 4: Switching to Negotiation History tab renders timeline and rounds', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'OFFER-2026-081'));
      await tester.pumpAndSettle();

      // Tap Negotiation History tab
      await tester.tap(find.byKey(const Key('tab-history')));
      await tester.pumpAndSettle();

      // Verify negotiation history ledger content
      expect(find.text('Broker Proposed Offer'), findsWidgets);
      expect(find.text('Broker Replied'), findsWidgets);
    });

    testWidgets('View 5: Switching to Documents tab renders attached documents', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'OFFER-2026-081'));
      await tester.pumpAndSettle();

      // Tap Documents tab
      await tester.tap(find.byKey(const Key('tab-documents')));
      await tester.pumpAndSettle();

      // Verify documents list
      expect(find.text('Attached Documents'), findsOneWidget);
      expect(find.text('Offer Sheet'), findsOneWidget);
      expect(find.text('Quality Specification'), findsOneWidget);
      expect(find.text('Other Terms'), findsOneWidget);
    });

    testWidgets('View 6: Error state renders with Retry and Back to Offers when API throws', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        offerId: 'OFFER-2026-081',
        repo: ThrowingOffersRepository(),
      ));
      await tester.pumpAndSettle();

      // Verify error state view
      expect(find.byKey(const Key('offer-details-error-state')), findsOneWidget);
      expect(find.text('Failed to load proposal details'), findsOneWidget);
      expect(find.byKey(const Key('offer-error-retry-button')), findsOneWidget);
      expect(find.byKey(const Key('offer-error-back-button')), findsOneWidget);
    });

    testWidgets('View 7: Unavailable state renders when proposal ID does not exist', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'NON-EXISTENT-PROPOSAL-ID'));
      await tester.pumpAndSettle();

      // Verify unavailable state view
      expect(find.byKey(const Key('offer-details-unavailable-state')), findsOneWidget);
      expect(find.text('Proposal Unavailable'), findsOneWidget);
      expect(find.byKey(const Key('offer-unavailable-back-button')), findsOneWidget);
    });

    testWidgets('Action: Tapping Make Counter Offer opens modal sheet and submits revision', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'OFFER-2026-081'));
      await tester.pumpAndSettle();

      final counterBtn = find.byKey(const Key('offer-make-counter-btn'));
      expect(counterBtn, findsOneWidget);
      await tester.tap(counterBtn);
      await tester.pumpAndSettle();

      // Modal bottom sheet is open
      expect(find.text('Submit Counter-Offer'), findsOneWidget);
      expect(find.byKey(const Key('counter-submit-btn')), findsOneWidget);

      // Tap confirm and submit
      await tester.tap(find.byKey(const Key('counter-submit-btn')));
      await tester.pumpAndSettle();

      // Status updated to COUNTERED
      expect(find.text('COUNTERED'), findsWidgets);
    });

    testWidgets('Action: Tapping Accept Offer opens confirmation dialog and accepts proposal', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'OFFER-2026-081'));
      await tester.pumpAndSettle();

      final acceptBtn = find.byKey(const Key('offer-accept-btn'));
      expect(acceptBtn, findsOneWidget);
      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Accept Offer Terms'), findsOneWidget);
      expect(find.byKey(const Key('offer-confirm-accept-btn')), findsOneWidget);

      // Confirm acceptance
      await tester.tap(find.byKey(const Key('offer-confirm-accept-btn')));
      await tester.pumpAndSettle();

      // Status updated to ACCEPTED
      expect(find.text('ACCEPTED'), findsWidgets);
    });

    testWidgets('Action: Tapping Decline Offer opens reason dialog and rejects proposal', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'OFFER-2026-081'));
      await tester.pumpAndSettle();

      final declineBtn = find.byKey(const Key('offer-decline-btn'));
      expect(declineBtn, findsOneWidget);
      await tester.tap(declineBtn);
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Decline Offer'), findsWidgets);
      expect(find.byKey(const Key('offer-confirm-reject-btn')), findsOneWidget);

      // Confirm decline
      await tester.tap(find.byKey(const Key('offer-confirm-reject-btn')));
      await tester.pumpAndSettle();

      // Status updated to REJECTED / DECLINED
      expect(find.text('REJECTED'), findsWidgets);
    });

    testWidgets('State: Expired proposal shows expiry banner and disables action buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'OFFER-2026-084'));
      await tester.pumpAndSettle();

      expect(find.text('EXPIRED'), findsWidgets);
      expect(find.textContaining('Offer Validity Expired'), findsOneWidget);
      expect(find.byKey(const Key('offer-make-counter-btn')), findsNothing);
      expect(find.byKey(const Key('offer-accept-btn')), findsNothing);
      expect(find.byKey(const Key('offer-decline-btn')), findsNothing);
    });

    testWidgets('Navigation: Back button triggers safe back navigation', (tester) async {
      await tester.pumpWidget(buildTestWidget(offerId: 'OFFER-2026-081'));
      await tester.pumpAndSettle();

      final backBtn = find.byKey(const Key('offer-details-back-button'));
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();
      // Verifies no unhandled navigation exception thrown
    });
  });
}
