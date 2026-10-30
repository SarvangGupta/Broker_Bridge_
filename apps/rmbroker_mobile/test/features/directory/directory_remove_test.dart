import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmbroker_mobile/features/directory/data/directory_repository.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_state.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/directory_controller.dart';
import 'package:rmbroker_mobile/features/directory/presentation/directory_screen.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/contact_details_sheet.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/directory_contact_card.dart';

/// Testable Mock Repository specifically instrumented for removal flow verification.
class TestableDirectoryRepository extends DirectoryRepository {
  List<DirectoryContact> contacts;
  final List<String> removedContactIds = [];
  bool simulateFailure = false;
  String failureErrorMessage = 'Database permission denied (RLS 42501)';

  TestableDirectoryRepository({required this.contacts});

  @override
  Future<DirectoryDataResult<DirectoryListPayload>> getContacts({
    String? role,
    String? search,
    String? status,
    int? limit,
    String? cursor,
  }) async {
    final filtered = contacts.where((c) {
      if (role == 'buyer' && c.role != ContactRole.buyer) return false;
      if (role == 'seller' && c.role != ContactRole.seller) return false;
      if (status == 'active' && !c.status) return false;
      if (status == 'inactive' && c.status) return false;
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        return c.name.toLowerCase().contains(q) ||
            c.companyName.toLowerCase().contains(q) ||
            c.mobile.contains(q);
      }
      return true;
    }).toList();

    return DirectorySuccess(
      DirectoryListPayload(
        contacts: filtered,
        stats: DirectorySummaryStats.fromContacts(filtered),
        hasMore: false,
      ),
    );
  }

  @override
  Future<DirectoryDataResult<ContactDetailsPayload>> getContactDetails(
    String contactId,
  ) async {
    final contact = contacts.firstWhere(
      (c) => c.id == contactId,
      orElse: () => contacts.isNotEmpty ? contacts.first : DirectoryContact(
        id: contactId,
        userId: 'u',
        companyId: 'comp',
        name: 'Test',
        companyName: 'Test Co',
        mobile: '+919876543210',
        role: ContactRole.buyer,
        status: true,
        isVerified: false,
        trustScore: 90,
        createdAt: DateTime.now(),
      ),
    );
    return DirectorySuccess(ContactDetailsPayload(contact: contact));
  }

  @override
  Future<DirectoryDataResult<bool>> removeContact(String contactId) async {
    if (simulateFailure) {
      return DirectoryError(message: failureErrorMessage);
    }
    removedContactIds.add(contactId);
    contacts.removeWhere((c) => c.id == contactId);
    return const DirectorySuccess(true);
  }
}

void main() {
  late DirectoryContact buyerContact;
  late DirectoryContact sellerContact;
  late TestableDirectoryRepository mockRepo;

  setUp(() {
    buyerContact = DirectoryContact(
      id: 'buyer-uuid-101',
      userId: 'user-b-1',
      companyId: 'company-b-1',
      name: 'Rajesh Sharma',
      companyName: 'Sharma Oil Mills',
      mobile: '+919876543210',
      role: ContactRole.buyer,
      status: true,
      isVerified: true,
      trustScore: 95,
      city: 'Kota',
      state: 'Rajasthan',
      createdAt: DateTime(2026, 1, 1),
    );

    sellerContact = DirectoryContact(
      id: 'seller-uuid-202',
      userId: 'user-s-2',
      companyId: 'company-s-2',
      name: 'Vikram Patel',
      companyName: 'Patel Agro Traders',
      mobile: '+919876543211',
      role: ContactRole.seller,
      status: true,
      isVerified: false,
      trustScore: 88,
      city: 'Jaipur',
      state: 'Rajasthan',
      createdAt: DateTime(2026, 1, 2),
    );

    mockRepo = TestableDirectoryRepository(
      contacts: [buyerContact, sellerContact],
    );
  });

  Widget buildTestApp({required DirectoryRepository repository}) {
    return ProviderScope(
      overrides: [
        directoryRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: DirectoryScreen(),
      ),
    );
  }

  group('RMBROKER-DIRECTORY-REMOVE-FIX-01: Remove Buyer/Seller Directory Flow', () {
    testWidgets('1. Buyer Removal: Prompts confirmation, executes backend removal, refreshes list', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(repository: mockRepo));
      await tester.pumpAndSettle();

      // Both contacts initially visible
      expect(find.text('Sharma Oil Mills'), findsOneWidget);
      expect(find.text('Patel Agro Traders'), findsOneWidget);

      // Tap remove button on the buyer contact card
      final buyerRemoveBtn = find.byKey(const Key('remove_contact_button_buyer-uuid-101'));
      expect(buyerRemoveBtn, findsOneWidget);
      await tester.tap(buyerRemoveBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog should be displayed with "Remove Buyer?"
      expect(find.text('Remove Buyer?'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to remove Sharma Oil Mills'), findsOneWidget);
      expect(find.byKey(const Key('confirm_remove_contact_button')), findsOneWidget);

      // Tap confirm Remove
      await tester.tap(find.byKey(const Key('confirm_remove_contact_button')));
      await tester.pumpAndSettle();

      // Verified: repository called, buyer contact removed from list
      expect(mockRepo.removedContactIds, contains('buyer-uuid-101'));
      expect(find.text('Sharma Oil Mills'), findsNothing);
      expect(find.text('Patel Agro Traders'), findsOneWidget);

      // Success snackbar shown
      expect(find.text('Sharma Oil Mills removed from your directory.'), findsOneWidget);
    });

    testWidgets('2. Seller Removal: Prompts confirmation, executes backend removal, refreshes list', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(repository: mockRepo));
      await tester.pumpAndSettle();

      // Tap remove button on the seller contact card
      final sellerRemoveBtn = find.byKey(const Key('remove_contact_button_seller-uuid-202'));
      expect(sellerRemoveBtn, findsOneWidget);
      await tester.tap(sellerRemoveBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog displayed with "Remove Seller?"
      expect(find.text('Remove Seller?'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to remove Patel Agro Traders'), findsOneWidget);

      // Tap confirm Remove
      await tester.tap(find.byKey(const Key('confirm_remove_contact_button')));
      await tester.pumpAndSettle();

      // Verified: repository called, seller contact removed from list
      expect(mockRepo.removedContactIds, contains('seller-uuid-202'));
      expect(find.text('Patel Agro Traders'), findsNothing);
      expect(find.text('Sharma Oil Mills'), findsOneWidget);

      // Success snackbar shown
      expect(find.text('Patel Agro Traders removed from your directory.'), findsOneWidget);
    });

    testWidgets('3. Cancel Removal in Confirmation Dialog leaves contact untouched', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(repository: mockRepo));
      await tester.pumpAndSettle();

      // Tap remove button on buyer
      await tester.tap(find.byKey(const Key('remove_contact_button_buyer-uuid-101')));
      await tester.pumpAndSettle();

      // Tap Cancel in dialog
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Repository was NOT called, contact remains visible
      expect(mockRepo.removedContactIds, isEmpty);
      expect(find.text('Sharma Oil Mills'), findsOneWidget);
      expect(find.text('Patel Agro Traders'), findsOneWidget);
    });

    testWidgets('4. Remove from Contact Details Sheet works and closes the sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ContactDetailsSheet.show(context, buyerContact),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open details sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Remove button inside details sheet
      final removeBtnInSheet = find.byKey(const Key('remove_contact_button'));
      expect(removeBtnInSheet, findsOneWidget);

      await tester.tap(removeBtnInSheet);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Remove Buyer?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_remove_contact_button')));
      await tester.pumpAndSettle();

      // Verified: repository called, sheet closed, success message shown
      expect(mockRepo.removedContactIds, contains('buyer-uuid-101'));
      expect(find.byType(ContactDetailsSheet), findsNothing);
      expect(find.text('Sharma Oil Mills removed from your directory.'), findsOneWidget);
    });

    testWidgets('5. Failure on Backend/RLS error: displays honest error message and keeps contact visible', (
      tester,
    ) async {
      mockRepo.simulateFailure = true;
      mockRepo.failureErrorMessage = 'Permission denied on crm_contacts (RLS 42501)';

      await tester.pumpWidget(buildTestApp(repository: mockRepo));
      await tester.pumpAndSettle();

      // Tap remove button
      await tester.tap(find.byKey(const Key('remove_contact_button_buyer-uuid-101')));
      await tester.pumpAndSettle();

      // Confirm remove
      await tester.tap(find.byKey(const Key('confirm_remove_contact_button')));
      await tester.pumpAndSettle();

      // Verified: error message shown, contact remains visible in list
      expect(find.text('Permission denied on crm_contacts (RLS 42501)'), findsOneWidget);
      expect(find.text('Sharma Oil Mills'), findsOneWidget);
    });

    testWidgets('6. Removal while filtered by role tab (Buyers tab) immediately updates list', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(repository: mockRepo));
      await tester.pumpAndSettle();

      // Switch to Buyers tab
      await tester.tap(find.byKey(const Key('tab_buyers')));
      await tester.pumpAndSettle();

      expect(find.text('Sharma Oil Mills'), findsOneWidget);
      expect(find.text('Patel Agro Traders'), findsNothing);

      // Remove buyer
      await tester.tap(find.byKey(const Key('remove_contact_button_buyer-uuid-101')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_remove_contact_button')));
      await tester.pumpAndSettle();

      // Buyer is now gone, empty state for buyers tab is shown
      expect(find.text('Sharma Oil Mills'), findsNothing);
      expect(find.text('No Buyers Registered'), findsOneWidget);
    });
  });
}
