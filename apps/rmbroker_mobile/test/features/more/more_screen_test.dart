import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmbroker_mobile/features/authentication/data/auth_repository.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';
import 'package:rmbroker_mobile/features/more/presentation/more_screen.dart';

class MockAuthRepository extends AuthRepository {
  final BrokerUser? mockUser;
  MockAuthRepository({this.mockUser});

  @override
  Future<BrokerUser?> getCurrentBroker() async {
    return mockUser ??
        const BrokerUser(
          id: 'b-001',
          email: 'varun@brokerbridge.in',
          fullName: 'Varun Broker Desk',
          role: 'broker',
          companyId: 'comp-001',
        );
  }
}

void main() {
  group('MoreScreen Navigation & Broker Tasks Tile (RB-FL-14F)', () {
    testWidgets('renders Broker Tasks & Follow-ups tile in Tools list', (tester) async {
      final mockAuth = MockAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MoreScreen(authRepository: mockAuth),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title and subtitle of the Broker Tasks entry
      expect(find.text('Broker Tasks & Follow-ups'), findsOneWidget);
      expect(
        find.text('Track action items, priorities & business follow-ups'),
        findsOneWidget,
      );

      // Verify checkSquare icon is present
      expect(find.byIcon(LucideIcons.checkSquare), findsOneWidget);

      // Verify other navigation entries remain intact without duplicates
      expect(find.text('Language / भाषा'), findsOneWidget);
      expect(find.text('Brokerage & Commission Ledger'), findsOneWidget);
      expect(find.text('Commission Invoices & Statements'), findsOneWidget);
      expect(find.text('Notifications & Activity Center'), findsOneWidget);
      expect(find.text('Security & Access Logs'), findsOneWidget);
      expect(find.text('Audit Trails & Reports'), findsOneWidget);
      expect(find.text('Fiduciary Disclaimer'), findsOneWidget);
    });

    testWidgets('tapping Broker Tasks & Follow-ups navigates to /tasks route', (tester) async {
      final mockAuth = MockAuthRepository();
      bool tasksRouteOpened = false;

      final router = GoRouter(
        initialLocation: '/more',
        routes: [
          GoRoute(
            path: '/more',
            builder: (context, state) => MoreScreen(authRepository: mockAuth),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) {
              tasksRouteOpened = true;
              return const Scaffold(
                body: Text('Tasks Screen Destination'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap Broker Tasks & Follow-ups tile
      final tasksTile = find.widgetWithText(ListTile, 'Broker Tasks & Follow-ups');
      expect(tasksTile, findsOneWidget);

      await tester.tap(tasksTile);
      await tester.pumpAndSettle();

      // Verify navigation to /tasks succeeded
      expect(tasksRouteOpened, isTrue);
      expect(find.text('Tasks Screen Destination'), findsOneWidget);
    });
  });
}
