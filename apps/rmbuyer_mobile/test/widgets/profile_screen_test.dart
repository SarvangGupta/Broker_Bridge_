import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/authentication/domain/buyer_user.dart';
import 'package:rmbuyer_mobile/features/profile/presentation/buyer_profile_screen.dart';

void main() {
  testWidgets('BuyerProfileScreen renders buyer identity, GST info, and counterparty shield', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const BuyerProfileScreen(
          user: BuyerUser(
            id: 'u-1',
            email: 'buyer@apexprocurement.com',
            fullName: 'Rajesh Singhal',
            role: 'buyer',
            companyName: 'Apex Grain Processors Pvt Ltd',
            companyGst: '08AABCA1234F1Z8',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Buyer Profile & Settings'), findsOneWidget);

    // Verify User Role Badge
    expect(find.text('BUYER PROCUREMENT ADMIN'), findsOneWidget);

    // Verify Enterprise info
    expect(find.text('Procuring Enterprise'), findsOneWidget);
    expect(find.text('GST VERIFIED'), findsOneWidget);

    // Verify Counterparty Shield Notice
    expect(find.text('Counterparty Isolation Shield'), findsOneWidget);

    // Verify Sign Out button
    expect(find.text('Sign Out of RMBuyer'), findsOneWidget);
  });
}
