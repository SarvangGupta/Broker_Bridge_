import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmbroker_mobile/app/app.dart';

void main() {
  testWidgets(
    'RMBrokerApp smoke test initializes and renders shell without errors',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: RMBrokerApp()));

      // Initial frame renders splash screen branding
      expect(find.text('RMBroker'), findsOneWidget);
      expect(find.text('Commodity Mandi Broker Desk'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Advance clock past the 1.2s splash timer so all pending timers complete cleanly
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    },
  );
}
