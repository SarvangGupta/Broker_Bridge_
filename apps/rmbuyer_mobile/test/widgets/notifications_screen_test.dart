import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/notifications/presentation/buyer_notifications_screen.dart';

void main() {
  testWidgets('BuyerNotificationsScreen renders notifications list', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const BuyerNotificationsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Counterparty Quote Received'), findsOneWidget);
    expect(find.text('Requirement Allocated'), findsOneWidget);
    expect(find.text('Shipment Dispatched'), findsOneWidget);
  });
}
