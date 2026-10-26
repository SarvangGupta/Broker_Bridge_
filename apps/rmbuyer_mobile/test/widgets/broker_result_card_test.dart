import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/search/domain/broker_model.dart';
import 'package:rmbuyer_mobile/features/search/presentation/widgets/broker_result_card.dart';

void main() {
  group('RMBUYER-BROKERS-UI-02: BrokerResultCard Widget Tests', () {
    testWidgets('Renders name, bracketed location, trust and chips with no contact actions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const broker = BrokerModel(
        id: 'b-1',
        name: 'Rajesh Verma',
        companyName: 'Jaipur Grain Broker Desk',
        location: 'Jaipur Mandi, Rajasthan',
        mobile: '+919829012345',
        trustScore: 98,
        isVerified: true,
        commoditiesHandled: ['Soybean', 'Chana', 'Wheat', 'Mustard', 'Maize', 'Tur'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: BrokerResultCard(broker: broker)),
        ),
      );

      expect(find.text('Rajesh Verma'), findsOneWidget);
      expect(find.text('(Jaipur Mandi, Rajasthan)'), findsOneWidget);
      expect(find.text('98 Trust'), findsOneWidget);
      expect(find.text('Soybean'), findsOneWidget);
      expect(find.text('Mustard'), findsOneWidget);
      expect(find.text('Maize'), findsNothing);
      expect(find.text('+2'), findsOneWidget);

      // Contact actions moved to the profile
      expect(find.text('Call Desk'), findsNothing);
      expect(find.text('WhatsApp'), findsNothing);
      expect(find.text('Jaipur Grain Broker Desk'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hides placeholder location and opens the broker profile on tap',
        (WidgetTester tester) async {
      const broker = BrokerModel(
        id: 'b-2',
        name: 'Placeholder Desk',
        companyName: 'Licensed Mandi Broker Desk',
        location: 'Mandi Trading Floor',
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: BrokerResultCard(broker: broker)),
          ),
          GoRoute(
            path: '/brokers/:id',
            builder: (_, state) => Text('profile ${state.pathParameters['id']}'),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );

      expect(find.text('Mandi Trading Floor'), findsNothing);
      expect(find.text('(Mandi Trading Floor)'), findsNothing);
      expect(find.text('Licensed Mandi Broker Desk'), findsNothing);

      await tester.tap(find.text('Placeholder Desk'));
      await tester.pumpAndSettle();
      expect(find.text('profile b-2'), findsOneWidget);
    });
  });
}
