import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/directory/data/directory_repository.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/directory_controller.dart';
import 'package:rmbroker_mobile/features/directory/presentation/directory_screen.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/contact_action_buttons.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/contact_details_sheet.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/contact_form_modal.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/directory_contact_card.dart';

class MockDirectoryRepository extends DirectoryRepository {
  final DirectoryDataResult<DirectoryListPayload> listResult;

  MockDirectoryRepository({required this.listResult});

  @override
  Future<DirectoryDataResult<DirectoryListPayload>> getContacts({
    String? role,
    String? search,
    String? status,
    int? limit,
    String? cursor,
  }) async =>
      listResult;
}

void main() {
  final sampleContacts = [
    DirectoryContact(
      id: 'c-101',
      userId: 'u-1',
      companyId: 'comp-1',
      name: 'Ramesh Agrawal',
      companyName: 'Malwa Agro Traders',
      mobile: '+919876543210',
      role: ContactRole.buyer,
      status: true,
      isVerified: true,
      trustScore: 98,
      city: 'Kota',
      state: 'Rajasthan',
      createdAt: DateTime.now(),
      openRequirementsCount: 3,
    ),
    DirectoryContact(
      id: 'c-102',
      userId: 'u-2',
      companyId: 'comp-2',
      name: 'Sunil Mittal',
      companyName: 'Jaipur Mustard Mill',
      mobile: '+919876543211',
      role: ContactRole.seller,
      status: true,
      isVerified: false,
      trustScore: 85,
      city: 'Jaipur',
      state: 'Rajasthan',
      createdAt: DateTime.now(),
      availableOffersCount: 4,
    ),
  ];

  final sampleStats = DirectorySummaryStats.fromContacts(sampleContacts);

  Widget createTestWidget({
    required DirectoryRepository repository,
    Size screenSize = const Size(412, 915),
  }) {
    return ProviderScope(
      overrides: [
        directoryRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: const DirectoryScreen(),
        ),
      ),
    );
  }

  group('DirectoryScreen UI & Interaction Tests', () {
    testWidgets('renders title, subtitle, search, role tabs and FAB; no summary metrics', (
      tester,
    ) async {
      final repo = MockDirectoryRepository(
        listResult: DirectorySuccess(
          DirectoryListPayload(contacts: sampleContacts, stats: sampleStats),
        ),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Directory'), findsOneWidget);
      expect(find.text('(Buyers & Sellers)'), findsOneWidget);
      expect(find.text('Total Counterparties'), findsNothing);
      expect(find.text('Active Buyers'), findsNothing);
      expect(find.text('Active Sellers'), findsNothing);
      expect(find.text('Search by name, company or phone number...'), findsOneWidget);
      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('Buyers (1)'), findsOneWidget);
      expect(find.text('Sellers (1)'), findsOneWidget);
      expect(find.byKey(const Key('filter_status_all')), findsNothing);
      expect(find.byKey(const Key('directory_refresh_button')), findsOneWidget);
      expect(find.byKey(const Key('directory_add_contact_button')), findsOneWidget);
      expect(find.byKey(const Key('directory_search_field')), findsOneWidget);
      expect(find.byKey(const Key('tab_all')), findsOneWidget);
      expect(find.byKey(const Key('tab_buyers')), findsOneWidget);
      expect(find.byKey(const Key('tab_sellers')), findsOneWidget);
      expect(find.byKey(const Key('add_contact_fab')), findsOneWidget);
    });

    testWidgets('renders compact rows with role, verified badge only when verified, and action buttons', (
      tester,
    ) async {
      final repo = MockDirectoryRepository(
        listResult: DirectorySuccess(
          DirectoryListPayload(contacts: sampleContacts, stats: sampleStats),
        ),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Malwa Agro Traders'), findsOneWidget);
      expect(find.text('Jaipur Mustard Mill'), findsOneWidget);
      expect(find.text('Ramesh Agrawal'), findsOneWidget);
      expect(find.text('Sunil Mittal'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('contact_card_c-101')), matching: find.text('Verified')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('contact_card_c-102')), matching: find.text('Verified')), findsNothing);
      expect(find.text('Buyer'), findsOneWidget);
      expect(find.text('Seller'), findsOneWidget);
      expect(find.text('Kota, Rajasthan'), findsOneWidget);
      expect(find.byType(ContactActionButtons), findsNWidgets(2));
      expect(find.byType(DirectoryContactCard), findsNWidgets(2));
    });

    testWidgets('displays honest unavailable state when backend contract is pending exposure', (
      tester,
    ) async {
      final repo = MockDirectoryRepository(
        listResult: const DirectoryUnavailable(
          contractNotice:
              'Authoritative endpoint /api/v1/broker/directory is pending backend exposure.',
        ),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Directory Contract Pending'), findsOneWidget);
      expect(find.textContaining('pending backend exposure'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);
      expect(find.byType(DirectoryContactCard), findsNothing);
    });

    testWidgets('switching role tabs filters list between Buyers and Sellers', (
      tester,
    ) async {
      final repo = MockDirectoryRepository(
        listResult: DirectorySuccess(
          DirectoryListPayload(contacts: sampleContacts, stats: sampleStats),
        ),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Tap Buyers tab
      await tester.tap(find.byKey(const Key('tab_buyers')));
      await tester.pumpAndSettle();

      expect(find.text('Malwa Agro Traders'), findsOneWidget);
      expect(find.text('Jaipur Mustard Mill'), findsNothing);

      // Tap Sellers tab
      await tester.tap(find.byKey(const Key('tab_sellers')));
      await tester.pumpAndSettle();

      expect(find.text('Malwa Agro Traders'), findsNothing);
      expect(find.text('Jaipur Mustard Mill'), findsOneWidget);
    });

    testWidgets('live search query filters counterparties by company name or city', (
      tester,
    ) async {
      final repo = MockDirectoryRepository(
        listResult: DirectorySuccess(
          DirectoryListPayload(contacts: sampleContacts, stats: sampleStats),
        ),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Enter search text 'Mustard'
      await tester.enterText(find.byKey(const Key('directory_search_field')), 'Mustard');
      await tester.pumpAndSettle();

      expect(find.text('Jaipur Mustard Mill'), findsOneWidget);
      expect(find.text('Malwa Agro Traders'), findsNothing);

      // Enter search text that matches nothing
      await tester.enterText(find.byKey(const Key('directory_search_field')), 'Nonexistent');
      await tester.pumpAndSettle();

      expect(find.text('No Search Results'), findsOneWidget);
      expect(find.textContaining('No contacts match "Nonexistent"'), findsOneWidget);
    });

    testWidgets('tapping FAB opens Add Contact modal with validation fields', (
      tester,
    ) async {
      final repo = MockDirectoryRepository(
        listResult: DirectorySuccess(
          DirectoryListPayload(contacts: sampleContacts, stats: sampleStats),
        ),
      );

      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Tap FAB
      await tester.tap(find.byKey(const Key('add_contact_fab')));
      await tester.pumpAndSettle();

      expect(find.byType(ContactFormModal), findsOneWidget);
      expect(find.text('Add Counterparty'), findsOneWidget);
      expect(find.byKey(const Key('contact_form_name_field')), findsOneWidget);
      expect(find.byKey(const Key('contact_form_company_field')), findsOneWidget);
      expect(find.byKey(const Key('contact_form_mobile_field')), findsOneWidget);
      expect(find.byKey(const Key('contact_form_submit_button')), findsOneWidget);

      // Scroll to submit button and tap with empty fields -> triggers validation errors
      await tester.ensureVisible(find.byKey(const Key('contact_form_submit_button')));
      await tester.tap(find.byKey(const Key('contact_form_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Contact person name must be at least 2 characters'), findsOneWidget);
      expect(find.text('Company name must be at least 2 characters'), findsOneWidget);
      expect(find.text('Mobile number is required'), findsOneWidget);
    });

    testWidgets('renders cleanly without overflow on compact 360x640 mobile screen', (
      tester,
    ) async {
      final repo = MockDirectoryRepository(
        listResult: DirectorySuccess(
          DirectoryListPayload(contacts: sampleContacts, stats: sampleStats),
        ),
      );

      await tester.pumpWidget(createTestWidget(
        repository: repo,
        screenSize: const Size(360, 640),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Directory'), findsOneWidget);
      expect(find.byType(DirectoryContactCard), findsNWidgets(2));
    });

    testWidgets('search matches contact name and phone number', (tester) async {
      final repo = MockDirectoryRepository(
        listResult: DirectorySuccess(DirectoryListPayload(contacts: sampleContacts, stats: sampleStats)),
      );
      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('directory_search_field')), 'Sunil');
      await tester.pumpAndSettle();
      expect(find.text('Jaipur Mustard Mill'), findsOneWidget);
      expect(find.text('Malwa Agro Traders'), findsNothing);

      await tester.enterText(find.byKey(const Key('directory_search_field')), '43210');
      await tester.pumpAndSettle();
      expect(find.text('Malwa Agro Traders'), findsOneWidget);
      expect(find.text('Jaipur Mustard Mill'), findsNothing);
    });

    testWidgets('row tap opens details; call and WhatsApp taps do not', (tester) async {
      final launched = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          launched.add(call.arguments is Map ? (call.arguments as Map)['url'].toString() : '${call.arguments}');
          return true;
        },
      );
      final repo = MockDirectoryRepository(
        listResult: DirectorySuccess(DirectoryListPayload(contacts: sampleContacts, stats: sampleStats)),
      );
      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();

      final row = find.byKey(const Key('contact_card_c-101'));
      await tester.tap(find.descendant(of: row, matching: find.byIcon(LucideIcons.phone)));
      await tester.pumpAndSettle();
      expect(find.byType(ContactDetailsSheet), findsNothing);

      await tester.tap(find.descendant(of: row, matching: find.byIcon(LucideIcons.messageSquare)));
      await tester.pumpAndSettle();
      expect(find.byType(ContactDetailsSheet), findsNothing);
      expect(launched.any((u) => u.contains('tel:')), isTrue);
      expect(launched.any((u) => u.contains('wa.me/919876543210')), isTrue);

      await tester.tap(find.descendant(of: row, matching: find.text('Malwa Agro Traders')));
      // The details sheet shows a loading spinner; pump fixed frames.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ContactDetailsSheet), findsOneWidget);
    });

    testWidgets('header Add Contact opens the existing form', (tester) async {
      final repo = MockDirectoryRepository(
        listResult: DirectorySuccess(DirectoryListPayload(contacts: sampleContacts, stats: sampleStats)),
      );
      await tester.pumpWidget(createTestWidget(repository: repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('directory_add_contact_button')));
      await tester.pumpAndSettle();
      expect(find.byType(ContactFormModal), findsOneWidget);
    });
  });
}
