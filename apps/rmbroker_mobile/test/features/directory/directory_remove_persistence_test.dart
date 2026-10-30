import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/directory/data/directory_repository.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/directory_controller.dart';
import 'package:rmbroker_mobile/features/directory/presentation/directory_screen.dart';

/// Test repository that simulates database persistence with soft removal (removed_at)
/// and synchronization protection against resurrection.
class PersistenceSimulatedDirectoryRepository extends DirectoryRepository {
  /// Internal database table rows representing public.crm_contacts
  final Map<String, Map<String, dynamic>> crmContactsDb = {};
  final Map<String, DirectoryContact> contactsDb = {};

  PersistenceSimulatedDirectoryRepository({
    required List<DirectoryContact> initialContacts,
  }) {
    for (final c in initialContacts) {
      contactsDb[c.id] = c;
      crmContactsDb[c.id] = {
        'id': c.id,
        'broker_id': 'broker-varun',
        'user_id': c.userId,
        'company_id': c.companyId,
        'removed_at': null,
        'created_at': c.createdAt.toIso8601String(),
      };
    }
  }

  @override
  Future<DirectoryDataResult<DirectoryListPayload>> getContacts({
    String? role,
    String? search,
    String? status,
    int? limit,
    String? cursor,
  }) async {
    // Only return contacts whose relationship in crm_contacts has removed_at == null
    final activeContacts = crmContactsDb.values
        .where((row) => row['removed_at'] == null)
        .map((row) => contactsDb[row['id']]!)
        .where((c) {
          if (role == 'buyer' && c.role != ContactRole.buyer) return false;
          if (role == 'seller' && c.role != ContactRole.seller) return false;
          if (status == 'active' && !c.status) return false;
          if (status == 'inactive' && c.status) return false;
          if (search != null && search.isNotEmpty) {
            return c.matchesFilters(search: search);
          }
          return true;
        })
        .toList();

    return DirectorySuccess(
      DirectoryListPayload(
        contacts: activeContacts,
        stats: DirectorySummaryStats.fromContacts(activeContacts),
        hasMore: false,
      ),
    );
  }

  @override
  Future<DirectoryDataResult<bool>> removeContact(String contactId) async {
    if (!crmContactsDb.containsKey(contactId)) {
      return const DirectoryError(message: 'Contact record not found.');
    }
    // Authoritative soft removal: set removed_at timestamp
    crmContactsDb[contactId]!['removed_at'] = DateTime.now().toIso8601String();
    return const DirectorySuccess(true);
  }

  @override
  Future<DirectoryDataResult<String>> restoreContact(String contactId) async {
    if (!crmContactsDb.containsKey(contactId)) {
      return const DirectoryError(message: 'Contact record not found.');
    }
    crmContactsDb[contactId]!['removed_at'] = null;
    return DirectorySuccess(contactId);
  }

  @override
  Future<DuplicateCheckResult> checkDuplicate({
    required String mobile,
    String? companyName,
    String? gstin,
  }) async {
    for (final row in crmContactsDb.values) {
      final contact = contactsDb[row['id']]!;
      if (contact.mobile == mobile) {
        final isRemoved = row['removed_at'] != null;
        return DuplicateCheckResult(
          isDuplicate: true,
          matchType: 'exact_mobile',
          duplicateCase: isRemoved ? DuplicateCase.previouslyRemoved : DuplicateCase.activeInDirectory,
          existingContactId: contact.id,
          existingContactName: contact.name,
          existingCompanyName: contact.companyName,
          existingMobile: contact.mobile,
          existingRole: contact.role.label,
        );
      }
    }
    return DuplicateCheckResult.none();
  }
}

void main() {
  group('RMBROKER-VARUN-DIRECTORY-REMOVE-PERSISTENCE-01 Tests', () {
    late List<DirectoryContact> initialVarunContacts;
    late PersistenceSimulatedDirectoryRepository repository;

    setUp(() {
      // 9 Buyers, 4 Sellers (Varun's exact initial state)
      initialVarunContacts = [
        // Buyers
        DirectoryContact(id: 'b1', userId: 'u_b1', companyId: 'c_b1', name: 'Rahul', companyName: 'Rahul123', mobile: '+919876543201', role: ContactRole.buyer, status: true, isVerified: true, trustScore: 95, createdAt: DateTime.now().subtract(const Duration(days: 10))),
        DirectoryContact(id: 'b2', userId: 'u_b2', companyId: 'c_b2', name: 'Rohan Gupta', companyName: 'Rohan Gupta Pvt. Ltd', mobile: '+919876543202', role: ContactRole.buyer, status: true, isVerified: true, trustScore: 90, createdAt: DateTime.now().subtract(const Duration(days: 9))),
        DirectoryContact(id: 'b3', userId: 'u_b3', companyId: 'c_b3', name: 'Vetkind Animal', companyName: 'Vetkind Corp', mobile: '+919876543203', role: ContactRole.buyer, status: true, isVerified: false, trustScore: 80, createdAt: DateTime.now().subtract(const Duration(days: 8))),
        DirectoryContact(id: 'b4', userId: 'u_b4', companyId: 'c_b4', name: 'Hari Shanker', companyName: 'Shiv Shanker Tr', mobile: '+919876543204', role: ContactRole.buyer, status: true, isVerified: false, trustScore: 85, createdAt: DateTime.now().subtract(const Duration(days: 7))),
        DirectoryContact(id: 'b5', userId: 'u_b5', companyId: 'c_b5', name: 'Ritu Singhania', companyName: 'Malwa Solvent', mobile: '+919876543205', role: ContactRole.buyer, status: true, isVerified: true, trustScore: 92, createdAt: DateTime.now().subtract(const Duration(days: 6))),
        DirectoryContact(id: 'b6', userId: 'u_b6', companyId: 'c_b6', name: 'Deepak Jain', companyName: 'Frontier Starch', mobile: '+919876543206', role: ContactRole.buyer, status: true, isVerified: true, trustScore: 88, createdAt: DateTime.now().subtract(const Duration(days: 5))),
        DirectoryContact(id: 'b7', userId: 'u_b7', companyId: 'c_b7', name: 'Pooja Agarwal', companyName: 'Golden Harvest', mobile: '+919876543207', role: ContactRole.buyer, status: true, isVerified: true, trustScore: 90, createdAt: DateTime.now().subtract(const Duration(days: 4))),
        DirectoryContact(id: 'b8', userId: 'u_b8', companyId: 'c_b8', name: 'Vikas Verma', companyName: 'North Dairy Feed', mobile: '+919876543208', role: ContactRole.buyer, status: true, isVerified: false, trustScore: 87, createdAt: DateTime.now().subtract(const Duration(days: 3))),
        DirectoryContact(id: 'b9', userId: 'u_b9', companyId: 'c_b9', name: 'Aman Sharma', companyName: 'AgrInnovate Feeds', mobile: '+919876543209', role: ContactRole.buyer, status: true, isVerified: true, trustScore: 91, createdAt: DateTime.now().subtract(const Duration(days: 2))),

        // Sellers
        DirectoryContact(id: 's1', userId: 'u_s1', companyId: 'c_s1', name: 'Parth', companyName: 'Parth Ltd.', mobile: '+919876543210', role: ContactRole.seller, status: true, isVerified: true, trustScore: 90, createdAt: DateTime.now().subtract(const Duration(days: 5))),
        DirectoryContact(id: 's2', userId: 'u_s2', companyId: 'c_s2', name: 'Suresh Meena', companyName: 'Shekhawati Wheat', mobile: '+919876543211', role: ContactRole.seller, status: true, isVerified: true, trustScore: 89, createdAt: DateTime.now().subtract(const Duration(days: 4))),
        DirectoryContact(id: 's3', userId: 'u_s3', companyId: 'c_s3', name: 'Mahesh Choudhary', companyName: 'Hadoti Grain Producers', mobile: '+919876543212', role: ContactRole.seller, status: true, isVerified: true, trustScore: 94, createdAt: DateTime.now().subtract(const Duration(days: 3))),
        DirectoryContact(id: 's4', userId: 'u_s4', companyId: 'c_s4', name: 'Rajesh Patidar', companyName: 'Kota Agro Warehousing', mobile: '+919876543213', role: ContactRole.seller, status: true, isVerified: true, trustScore: 93, createdAt: DateTime.now().subtract(const Duration(days: 1))),
      ];
      repository = PersistenceSimulatedDirectoryRepository(initialContacts: initialVarunContacts);
    });

    testWidgets('1. Removing a buyer permanently decreases count 9 -> 8 and does not bounce back to 9 on refresh', (tester) async {
      final container = ProviderContainer(
        overrides: [
          directoryRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DirectoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial count: 13 total, 9 buyers, 4 sellers
      final notifier = container.read(directoryControllerProvider.notifier);
      expect(container.read(directoryControllerProvider).allContacts.length, 13);
      expect(container.read(directoryControllerProvider).stats.buyersCount, 9);
      expect(container.read(directoryControllerProvider).stats.sellersCount, 4);

      // Remove buyer b9 (Aman Sharma)
      final removeSuccess = await notifier.removeContact('b9');
      expect(removeSuccess, isTrue);
      await tester.pumpAndSettle();

      // State after removal: 12 total, 8 buyers, 4 sellers
      expect(container.read(directoryControllerProvider).allContacts.length, 12);
      expect(container.read(directoryControllerProvider).stats.buyersCount, 8);
      expect(container.read(directoryControllerProvider).stats.sellersCount, 4);

      // Simulate pull-to-refresh / refetch: count MUST remain 8 (NOT 9!)
      await notifier.loadContacts(isRefresh: true);
      await tester.pumpAndSettle();

      expect(container.read(directoryControllerProvider).allContacts.length, 12);
      expect(container.read(directoryControllerProvider).stats.buyersCount, 8);
      expect(container.read(directoryControllerProvider).stats.sellersCount, 4);

      // Verify DB row has removed_at set
      expect(repository.crmContactsDb['b9']!['removed_at'], isNotNull);
    });

    testWidgets('2. Removing a seller permanently decreases count 4 -> 3 and persists across refresh', (tester) async {
      final container = ProviderContainer(
        overrides: [
          directoryRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DirectoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final notifier = container.read(directoryControllerProvider.notifier);
      expect(container.read(directoryControllerProvider).stats.sellersCount, 4);

      // Remove seller s4 (Rajesh Patidar)
      final removeSuccess = await notifier.removeContact('s4');
      expect(removeSuccess, isTrue);
      await tester.pumpAndSettle();

      expect(container.read(directoryControllerProvider).stats.sellersCount, 3);

      // Refresh directory
      await notifier.loadContacts(isRefresh: true);
      await tester.pumpAndSettle();

      expect(container.read(directoryControllerProvider).stats.sellersCount, 3);
      expect(repository.crmContactsDb['s4']!['removed_at'], isNotNull);
    });

    testWidgets('3. Re-adding a previously removed counterparty identifies DuplicateCase.previouslyRemoved and restores contact', (tester) async {
      // 1. Remove buyer b1 (Rahul)
      await repository.removeContact('b1');
      expect(repository.crmContactsDb['b1']!['removed_at'], isNotNull);

      // 2. Duplicate check when entering Rahul's mobile
      final dupCheck = await repository.checkDuplicate(mobile: '+919876543201');
      expect(dupCheck.isDuplicate, isTrue);
      expect(dupCheck.duplicateCase, DuplicateCase.previouslyRemoved);
      expect(dupCheck.existingContactId, 'b1');

      // 3. Restore counterparty
      final restoreResult = await repository.restoreContact(dupCheck.existingContactId!);
      expect(restoreResult, isA<DirectorySuccess<String>>());
      expect(repository.crmContactsDb['b1']!['removed_at'], isNull);

      // 4. Directory query now returns Rahul again
      final refreshed = await repository.getContacts();
      expect(refreshed, isA<DirectorySuccess<DirectoryListPayload>>());
      final contacts = (refreshed as DirectorySuccess<DirectoryListPayload>).data.contacts;
      expect(contacts.any((c) => c.id == 'b1'), isTrue);
    });
  });
}

