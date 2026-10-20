import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/core/services/contact_launcher_service.dart';
import 'package:rmbuyer_mobile/features/search/domain/broker_model.dart';
import 'package:rmbuyer_mobile/features/search/presentation/widgets/broker_result_card.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group('RB-BUYER-02: BrokerResultCard Widget Tests', () {
    testWidgets('Scenario 10 & 11: Renders broker info, trust score, and triggers Call & WhatsApp actions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      Uri? launchedUri;

      final fakeLauncher = ContactLauncherService(
        launchUrlFn: (uri, {mode = LaunchMode.platformDefault}) async {
          launchedUri = uri;
          return true;
        },
      );

      const broker = BrokerModel(
        id: 'b-1',
        name: 'Rajesh Verma',
        companyName: 'Jaipur Grain Broker Desk',
        location: 'Jaipur Mandi, Rajasthan',
        mobile: '+919829012345',
        trustScore: 98,
        isVerified: true,
        commoditiesHandled: ['Yellow Soybean', 'Desi Chana'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: BrokerResultCard(
              broker: broker,
              contactLauncher: fakeLauncher,
            ),
          ),
        ),
      );

      // Verify Header & Broker Info
      expect(find.text('Rajesh Verma'), findsOneWidget);
      expect(find.text('Jaipur Grain Broker Desk'), findsOneWidget);
      expect(find.text('Jaipur Mandi, Rajasthan'), findsOneWidget);
      expect(find.text('98 Trust'), findsOneWidget);
      expect(find.text('GST VERIFIED'), findsOneWidget);

      // Verify Commodity Chips
      expect(find.text('Yellow Soybean'), findsOneWidget);
      expect(find.text('Desi Chana'), findsOneWidget);

      // Verify Call Button & Action
      expect(find.text('Call Desk'), findsOneWidget);
      await tester.tap(find.text('Call Desk'));
      await tester.pump();
      expect(launchedUri.toString(), 'tel:+919829012345');

      // Verify WhatsApp Button & Action
      expect(find.text('WhatsApp'), findsOneWidget);
      await tester.tap(find.text('WhatsApp'));
      await tester.pump();
      expect(launchedUri!.host, 'wa.me');
      expect(launchedUri!.path, '/919829012345');
    });

    testWidgets('Scenario 12: Missing contact information disables actions gracefully without exposing private data',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const brokerNoPhone = BrokerModel(
        id: 'b-no-phone',
        name: 'Desk Without Mobile',
        companyName: 'Central Mandi Traders',
        mobile: null, // Missing mobile
        trustScore: 85,
        isVerified: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: BrokerResultCard(
              broker: brokerNoPhone,
            ),
          ),
        ),
      );

      // Verify buttons exist but are disabled (onPressed is null)
      final callBtn = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Call Desk'));
      final waBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'WhatsApp'));

      expect(callBtn.onPressed, isNull);
      expect(waBtn.onPressed, isNull);
      expect(find.text('GST VERIFIED'), findsNothing);
    });
  });
}
