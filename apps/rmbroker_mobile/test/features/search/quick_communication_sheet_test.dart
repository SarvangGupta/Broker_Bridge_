import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/features/search/domain/search_result.dart';
import 'package:rmbroker_mobile/features/search/presentation/controllers/quick_dial_controller.dart';
import 'package:rmbroker_mobile/features/search/presentation/widgets/quick_communication_sheet.dart';

void main() {
  group('QuickCommunicationSheet Widget & Speed-Dial Tests', () {
    final sampleContacts = [
      const QuickDialContactItem(
        id: 'qd-1',
        name: 'Gopal Sharma',
        companyName: 'Sharma Pulses Jaipur',
        role: 'Buyer',
        mobile: '+919829011111',
        formattedMobile: '+91 98290 11111',
        isVerified: true,
      ),
      const QuickDialContactItem(
        id: 'qd-2',
        name: 'Gopal Sharma',
        companyName: 'Bikaner Agro Traders',
        role: 'Seller',
        mobile: '+919829022222',
        formattedMobile: '+91 98290 22222',
        isVerified: false,
      ),
    ];

    Widget createSheetWidget() {
      return ProviderScope(
        overrides: [
          quickDialContactsProvider.overrideWith((ref) => sampleContacts),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: QuickCommunicationSheet(),
          ),
        ),
      );
    }

    testWidgets('renders Communication Desk header and Broker Mediation Firewall banner', (
      tester,
    ) async {
      await tester.pumpWidget(createSheetWidget());
      await tester.pumpAndSettle();

      expect(find.text('Communication Desk'), findsOneWidget);
      expect(find.text('Speed-dial authorized counterparties'), findsOneWidget);
      expect(
        find.textContaining('broker-mediated. Zero direct buyer-seller negotiation'),
        findsOneWidget,
      );
    });

    testWidgets('distinguishes similar contacts using company name and role tags', (
      tester,
    ) async {
      await tester.pumpWidget(createSheetWidget());
      await tester.pumpAndSettle();

      expect(find.text('Gopal Sharma'), findsNWidgets(2));
      expect(find.text('Sharma Pulses Jaipur'), findsOneWidget);
      expect(find.text('Bikaner Agro Traders'), findsOneWidget);
      expect(find.text('BUYER'), findsOneWidget);
      expect(find.text('SELLER'), findsOneWidget);

      // Verify Call and WhatsApp buttons are available for each contact
      expect(find.byIcon(LucideIcons.phone), findsNWidgets(2));
      expect(find.byIcon(LucideIcons.messageCircle), findsNWidgets(2));
    });

    testWidgets('filters counterparties using in-sheet filter input', (
      tester,
    ) async {
      await tester.pumpWidget(createSheetWidget());
      await tester.pumpAndSettle();

      final filterInput = find.byType(TextField);
      expect(filterInput, findsOneWidget);

      await tester.enterText(filterInput, 'Bikaner');
      await tester.pumpAndSettle();

      expect(find.text('Bikaner Agro Traders'), findsOneWidget);
      expect(find.text('Sharma Pulses Jaipur'), findsNothing);
    });
  });
}
