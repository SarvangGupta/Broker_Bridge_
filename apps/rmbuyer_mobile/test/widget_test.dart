import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/app.dart';

void main() {
  testWidgets(
    'RMBuyerApp smoke test initializes and renders shell without runtime errors',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: RMBuyerApp()));

      // Initial frame renders splash screen branding
      expect(find.text('RMBuyer'), findsOneWidget);
      expect(find.text('Enterprise Commodity Buyer Portal'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Advance clock past the 1.0s splash timer so all timers complete cleanly
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    },
  );
}
