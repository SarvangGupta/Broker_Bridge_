import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/core/services/contact_launcher_service.dart';
import 'package:rmbuyer_mobile/features/search/domain/broker_model.dart';
import 'package:rmbuyer_mobile/features/search/presentation/broker_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group('RB-BUYER-02: BrokerProfileScreen Widget Tests', () {
    testWidgets('Scenario 9: Renders verified broker profile details, GST, and contact CTAs',
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
        id: 'b354958e-779a-41f2-b7a3-5899eca32e32',
        name: 'Rajesh Verma',
        companyName: 'Jaipur Grain Broker Desk',
        companyGst: '08AAACJ1234A1Z1',
        location: 'Jaipur Mandi, Rajasthan',
        mobile: '+919829012345',
        trustScore: 98,
        isVerified: true,
        commoditiesHandled: ['Yellow Soybean', 'Desi Chana', 'Wheat (Sharbati)'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BrokerProfileScreen(
            brokerId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
            initialBroker: broker,
            contactLauncher: fakeLauncher,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Identity
      expect(find.text('Broker Desk Profile'), findsOneWidget);
      expect(find.text('Rajesh Verma'), findsOneWidget);
      expect(find.text('(Jaipur Mandi, Rajasthan)'), findsOneWidget);
      expect(find.text('98 Trust'), findsOneWidget);

      // Verify About rows
      expect(find.text('Mandi Location'), findsOneWidget);
      expect(find.text('Jaipur Mandi, Rajasthan'), findsOneWidget);
      expect(find.text('Yellow Soybean, Desi Chana, Wheat (Sharbati)'), findsOneWidget);
      expect(find.text('98 / 100'), findsOneWidget);
      expect(find.text('Jaipur Grain Broker Desk'), findsOneWidget);
      expect(find.text('08AAACJ1234A1Z1'), findsOneWidget);

      // Verify header commodity chips
      expect(find.text('Yellow Soybean'), findsOneWidget);
      expect(find.text('Wheat (Sharbati)'), findsOneWidget);

      // Contact actions near the top
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);

      await tester.tap(find.byKey(const Key('broker-call')));
      await tester.pump();
      expect(launchedUri.toString(), 'tel:+919829012345');

      await tester.tap(find.byKey(const Key('broker-whatsapp')));
      await tester.pump();
      expect(launchedUri!.host, 'wa.me');

      // Verify Primary Action
      expect(find.text('Post Requirement to this Broker Desk'), findsOneWidget);

      // Verify Fiduciary Shield Notice
      expect(find.textContaining('Seller identities stay protected.'), findsOneWidget);
    });

    testWidgets('Broker without a number shows no contact buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const BrokerProfileScreen(
            brokerId: 'b-no-phone',
            initialBroker: BrokerModel(id: 'b-no-phone', name: 'Desk Without Mobile'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('broker-call')), findsNothing);
      expect(find.byKey(const Key('broker-whatsapp')), findsNothing);
      expect(find.textContaining('pending administrative verification'), findsOneWidget);
    });
  });
}
