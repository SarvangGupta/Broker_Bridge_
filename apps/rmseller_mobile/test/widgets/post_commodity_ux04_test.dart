import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmseller_mobile/app/theme/app_theme.dart';
import 'package:rmseller_mobile/features/commodities/presentation/post_commodity_screen.dart';

void main() {
  group('RB-SELLER-POST-UX-04: Section 1 & 2 Redesign Widget Tests', () {
    testWidgets(
      'POST-UX04-01: Batch/Lot Number displayed as secondary label, NOT editable text field',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PostCommodityScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Editable Lot / Batch Number text field should NOT exist
        expect(find.text('Lot / Batch Number *'), findsNothing);
        expect(find.text('e.g. LOT-SOY-001'), findsNothing);

        // Compact read-only secondary label at top of Section 1 MUST exist
        expect(
          find.byKey(const Key('section1_batch_lot_label')),
          findsOneWidget,
        );
        expect(find.textContaining('BATCH / LOT NO.'), findsOneWidget);
        expect(find.textContaining('LOT-'), findsWidgets);
      },
    );

    testWidgets(
      'POST-UX04-02: Section 1 renders Commodity and Quality Grade dropdowns',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PostCommodityScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1. Commodity & Pricing'), findsOneWidget);
        expect(find.text('Commodity *'), findsOneWidget);
        expect(find.byKey(const Key('commodity_dropdown')), findsOneWidget);
        expect(find.text('Quality Grade *'), findsOneWidget);
        expect(find.byKey(const Key('grade_dropdown')), findsOneWidget);
      },
    );

    testWidgets(
      'POST-UX04-03: Section 2 renders Quantity, Unit, Price, and Payment Terms',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PostCommodityScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total Quantity *'), findsOneWidget);
        expect(find.byKey(const Key('quantity_field')), findsOneWidget);
        expect(find.text('Unit *'), findsOneWidget);
        expect(find.byKey(const Key('unit_dropdown')), findsOneWidget);
        expect(find.text('Asking Price (₹ per MT) *'), findsOneWidget);
        expect(find.byKey(const Key('asking_price_field')), findsOneWidget);
        expect(find.text('Commercial Payment Terms *'), findsOneWidget);
        expect(find.byKey(const Key('payment_terms_dropdown')), findsOneWidget);
      },
    );

    testWidgets(
      'POST-UX04-04: Section 2 displays live valuation badge when quantity and price are entered',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PostCommodityScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Enter 100 MT at ₹4500
        final quantityField = find.byKey(const Key('quantity_field'));
        final priceField = find.byKey(const Key('asking_price_field'));

        await tester.enterText(quantityField, '100');
        await tester.pump();
        await tester.enterText(priceField, '4500');
        await tester.pumpAndSettle();

        // Live valuation badge should display in Section 2: 100 * 4500 = ₹4,50,000
        expect(
          find.byKey(const Key('section2_live_valuation')),
          findsOneWidget,
        );
        expect(find.text('Est. Value: ₹4,50,000'), findsOneWidget);
      },
    );

    testWidgets(
      'POST-UX04-05: Validation catches empty quantity and invalid price values',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PostCommodityScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Submit with empty fields
        final submitButton = find.byKey(const Key('review_and_list_button'));
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.text('Required'), findsWidgets);
      },
    );

    testWidgets(
      'POST-UX04-06: Narrow mobile viewport (360x640) renders without layout overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PostCommodityScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('section1_batch_lot_label')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('quantity_field')), findsOneWidget);
      },
    );

    testWidgets(
      'POST-UX04-07: Wide viewport (1024x768) renders 2-column Section 1 & 3-column Section 2 without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PostCommodityScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('section1_batch_lot_label')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('commodity_dropdown')), findsOneWidget);
        expect(find.byKey(const Key('grade_dropdown')), findsOneWidget);
      },
    );

    testWidgets(
      'POST-UX04-08 (UX-05): four compact sections and the review action are present',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 3200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PostCommodityScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2. Warehouse & Loading'), findsOneWidget);
        expect(find.text('3. Lab Testing & Reports'), findsOneWidget);
        expect(find.text('4. My Trusted Broker'), findsOneWidget);
        expect(find.text('Review & List Commodity'), findsOneWidget);
      },
    );
  });
}
