import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_state.dart';

void main() {
  group('Directory Domain Models Tests', () {
    final sampleJson = {
      'id': 'contact-001',
      'userId': 'user-101',
      'companyId': 'comp-201',
      'name': 'Ramesh Agrawal',
      'companyName': 'Malwa Agro Traders',
      'mobile': '+919876543210',
      'email': 'ramesh@malwaagro.com',
      'role': 'buyer',
      'status': true,
      'isVerified': true,
      'trustScore': 98,
      'city': 'Kota',
      'state': 'Rajasthan',
      'createdAt': '2026-10-15T10:00:00Z',
      'openRequirementsCount': 3,
      'availableOffersCount': 0,
      'activeDealsCount': 1,
    };

    test('DirectoryContact parses JSON correctly and computes properties', () {
      final contact = DirectoryContact.fromJson(sampleJson);

      expect(contact.id, equals('contact-001'));
      expect(contact.name, equals('Ramesh Agrawal'));
      expect(contact.companyName, equals('Malwa Agro Traders'));
      expect(contact.role, equals(ContactRole.buyer));
      expect(contact.status, isTrue);
      expect(contact.isVerified, isTrue);
      expect(contact.trustScore, equals(98));
      expect(contact.locationLabel, equals('Kota, Rajasthan'));
      expect(contact.formattedMobile, equals('+91 98765 43210'));
      expect(contact.totalMandatesCount, equals(4));
    });

    test('DirectorySummaryStats calculates counts accurately from contact list', () {
      final contacts = [
        DirectoryContact(
          id: 'c1',
          userId: 'u1',
          companyId: 'comp1',
          name: 'Buyer 1',
          companyName: 'B1 Corp',
          mobile: '+919876543210',
          role: ContactRole.buyer,
          status: true,
          createdAt: DateTime.now(),
          openRequirementsCount: 2,
        ),
        DirectoryContact(
          id: 'c2',
          userId: 'u2',
          companyId: 'comp2',
          name: 'Seller 1',
          companyName: 'S1 Oils',
          mobile: '+919876543211',
          role: ContactRole.seller,
          status: true,
          createdAt: DateTime.now(),
          availableOffersCount: 5,
        ),
        DirectoryContact(
          id: 'c3',
          userId: 'u3',
          companyId: 'comp3',
          name: 'Archived Buyer',
          companyName: 'Inactive Ltd',
          mobile: '+919876543212',
          role: ContactRole.buyer,
          status: false,
          createdAt: DateTime.now(),
        ),
      ];

      final stats = DirectorySummaryStats.fromContacts(contacts);

      expect(stats.totalContacts, equals(3));
      expect(stats.buyersCount, equals(1)); // Only active counted
      expect(stats.sellersCount, equals(1));
      expect(stats.activeMandatesCount, equals(7)); // 2 + 5
    });

    test('DirectoryState filters contacts by role, status, and search query', () {
      final contacts = [
        DirectoryContact(
          id: 'c1',
          userId: 'u1',
          companyId: 'comp1',
          name: 'Ramesh Agrawal',
          companyName: 'Malwa Agro Traders',
          mobile: '+919876543210',
          role: ContactRole.buyer,
          city: 'Kota',
          status: true,
          createdAt: DateTime.now(),
        ),
        DirectoryContact(
          id: 'c2',
          userId: 'u2',
          companyId: 'comp2',
          name: 'Sunil Mittal',
          companyName: 'Jaipur Mustard Mill',
          mobile: '+919876543211',
          role: ContactRole.seller,
          city: 'Jaipur',
          status: true,
          createdAt: DateTime.now(),
        ),
        DirectoryContact(
          id: 'c3',
          userId: 'u3',
          companyId: 'comp3',
          name: 'Devendra Patel',
          companyName: 'Udaipur Agro',
          mobile: '+919876543212',
          role: ContactRole.buyer,
          city: 'Udaipur',
          status: false,
          createdAt: DateTime.now(),
        ),
      ];

      final baseState = DirectoryState(
        status: DirectoryStatus.loaded,
        allContacts: contacts,
        stats: DirectorySummaryStats.fromContacts(contacts),
      );

      // Filter by role: Buyers
      final buyersOnly = baseState.copyWith(activeTab: 'buyer').filteredContacts;
      expect(buyersOnly.length, equals(2)); // c1 and c3

      // Filter by role: Sellers
      final sellersOnly = baseState.copyWith(activeTab: 'seller').filteredContacts;
      expect(sellersOnly.length, equals(1)); // c2
      expect(sellersOnly.first.name, equals('Sunil Mittal'));

      // Filter by status: Active only
      final activeOnly = baseState.copyWith(statusFilter: 'active').filteredContacts;
      expect(activeOnly.length, equals(2));

      // Filter by status: Archived only
      final archivedOnly = baseState.copyWith(statusFilter: 'inactive').filteredContacts;
      expect(archivedOnly.length, equals(1));
      expect(archivedOnly.first.name, equals('Devendra Patel'));

      // Search by city
      final kotaSearch = baseState.copyWith(searchQuery: 'kota').filteredContacts;
      expect(kotaSearch.length, equals(1));
      expect(kotaSearch.first.city, equals('Kota'));

      // Search by phone digits
      final phoneSearch = baseState.copyWith(searchQuery: '43211').filteredContacts;
      expect(phoneSearch.length, equals(1));
      expect(phoneSearch.first.name, equals('Sunil Mittal'));
    });
  });
}
