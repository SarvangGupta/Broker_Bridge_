import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/directory/data/directory_repository.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';
import 'package:rmbroker_mobile/features/directory/domain/gst_certificate_data.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/directory_controller.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/buyer_discovery_sheet.dart';

class _FakeRepo extends DirectoryRepository {
  final List<DiscoverableBuyer> results;
  final added = <String>[];
  String? searchedCategory;
  int listLoads = 0;

  _FakeRepo(this.results);

  @override
  Future<DirectoryDataResult<List<DiscoverableBuyer>>> discoverBuyers({
    required String search,
    String? categoryId,
  }) async {
    searchedCategory = categoryId;
    return DirectorySuccess(results);
  }

  @override
  Future<DirectoryDataResult<String>> addExistingBuyer(String buyerUserId) async {
    added.add(buyerUserId);
    return const DirectorySuccess('contact-1');
  }

  @override
  Future<List<InterestedCategory>> getCategories() async => const [];

  @override
  Future<DirectoryDataResult<DirectoryListPayload>> getContacts({
    String? role,
    String? search,
    String? status,
    String? categoryId,
    int? limit,
    String? cursor,
  }) async {
    listLoads++;
    return const DirectorySuccess(DirectoryListPayload(contacts: []));
  }
}

Future<void> _pumpAndSearch(WidgetTester tester, _FakeRepo repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [directoryRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: BuyerDiscoverySheet())),
    ),
  );
  await tester.enterText(find.byKey(const Key('buyer_discovery_search')), 'Asha');
  await tester.pump(DirectoryController.searchDebounce);
  await tester.pump();
}

void main() {
  const buyer = DiscoverableBuyer(
    userId: 'u1',
    name: 'Asha',
    companyName: 'Asha Traders',
    gstVerificationStatus: CounterpartyGstStatus.gstPending,
  );

  test('fromJson keeps the canonical id and treats no categories as All Categories', () {
    final parsed = DiscoverableBuyer.fromJson(const {
      'userId': 'u1',
      'name': 'Asha',
      'companyName': 'Asha Traders',
      'interestedCategories': [],
    });
    expect(parsed.userId, 'u1');
    expect(parsed.categoriesLabel, 'All Categories');
    expect(parsed.isAlreadyAdded, isFalse);
  });

  testWidgets('adding links by the existing id and refreshes the directory', (tester) async {
    final repo = _FakeRepo(const [buyer]);
    await _pumpAndSearch(tester, repo);

    expect(find.textContaining('All Categories'), findsOneWidget);
    expect(find.textContaining('Verification Pending'), findsOneWidget);

    final loadsBefore = repo.listLoads;
    await tester.tap(find.text('Add to My List'));
    await tester.pumpAndSettle();

    expect(repo.added, ['u1']);
    expect(repo.listLoads, greaterThan(loadsBefore));
    expect(find.text('Already Added'), findsOneWidget);
    expect(find.text('Add to My List'), findsNothing);
  });

  testWidgets('a linked buyer shows Already Added and cannot be added again', (tester) async {
    final repo = _FakeRepo(const [
      DiscoverableBuyer(userId: 'u1', name: 'Asha', companyName: 'Asha Traders', contactId: 'c1'),
    ]);
    await _pumpAndSearch(tester, repo);

    expect(find.text('Already Added'), findsOneWidget);
    expect(find.text('Add to My List'), findsNothing);
  });

  test('the filter rule is shared with the directory list', () {
    final contact = DirectoryContact(
      id: 'c1',
      userId: 'u1',
      companyId: 'co1',
      name: 'Asha',
      companyName: 'Asha Traders',
      mobile: '',
      role: ContactRole.buyer,
      createdAt: DateTime(2026),
      interestedCategories: const [InterestedCategory(id: 'grains', name: 'Grains')],
    );
    expect(contact.matchesFilters(categoryId: 'grains'), isTrue);
    expect(contact.matchesFilters(categoryId: 'oilseeds'), isFalse);
    expect(contact.copyWith(interestedCategories: const []).matchesFilters(categoryId: 'oilseeds'), isTrue);
  });
}
