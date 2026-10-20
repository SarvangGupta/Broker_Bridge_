import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/authentication/presentation/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders buyer branding, fields, and disclaimer', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );

    expect(find.text('RMBuyer'), findsOneWidget);
    expect(find.text('Procurement Buyer Workstation Login'), findsOneWidget);
    expect(find.text('Work Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In to RMBuyer'), findsOneWidget);
    expect(find.textContaining('Buyer Notice:'), findsOneWidget);

    // Tap submit with empty credentials should trigger validation message
    await tester.tap(find.text('Sign In to RMBuyer'));
    await tester.pump();

    expect(find.text('Please enter both your work email and password.'), findsOneWidget);

    // Tap fill demo credentials fills the input fields
    await tester.tap(find.text('Fill Buyer Demo Credentials'));
    await tester.pump();

    expect(find.text('buyer.procurement@brokerbridge.com'), findsOneWidget);
  });
}
