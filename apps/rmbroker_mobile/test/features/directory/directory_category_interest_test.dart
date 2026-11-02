import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/directory_contact_card.dart';

const _grains = InterestedCategory(id: 'grains', name: 'Grains & Cereals');
const _oilseeds = InterestedCategory(id: 'oilseeds', name: 'Oilseeds');

DirectoryContact _contact({
  ContactRole role = ContactRole.buyer,
  List<InterestedCategory> categories = const [],
}) {
  return DirectoryContact(
    id: 'c1',
    userId: 'u1',
    companyId: 'co1',
    name: 'Asha',
    companyName: 'Asha Traders',
    mobile: '+919876543210',
    role: role,
    createdAt: DateTime(2026),
    interestedCategories: categories,
  );
}

void main() {
  group('matchesCategory', () {
    test('buyer with no categories is visible under every category', () {
      final buyer = _contact();
      expect(buyer.matchesCategory('grains'), isTrue);
      expect(buyer.matchesCategory('oilseeds'), isTrue);
    });

    test('buyer with one category is visible only under it', () {
      final buyer = _contact(categories: const [_grains]);
      expect(buyer.matchesCategory('grains'), isTrue);
      expect(buyer.matchesCategory('oilseeds'), isFalse);
    });

    test('buyer with several categories is visible under each', () {
      final buyer = _contact(categories: const [_grains, _oilseeds]);
      expect(buyer.matchesCategory('grains'), isTrue);
      expect(buyer.matchesCategory('oilseeds'), isTrue);
      expect(buyer.matchesCategory('pulses'), isFalse);
    });

    test('no category filter keeps every contact', () {
      expect(_contact(categories: const [_grains]).matchesCategory(null), isTrue);
    });

    test('clearing categories widens and selecting them narrows', () {
      final selected = _contact(categories: const [_grains]);
      final cleared = selected.copyWith(interestedCategories: const []);
      expect(cleared.matchesCategory('oilseeds'), isTrue);
      expect(cleared.interestedInLabel, 'Interested in: All Categories');

      final narrowed = cleared.copyWith(interestedCategories: const [_grains]);
      expect(narrowed.matchesCategory('oilseeds'), isFalse);
    });

    test('sellers are not narrowed by the buyer preference', () {
      expect(_contact(role: ContactRole.seller).matchesCategory('grains'), isTrue);
    });
  });

  group('directory card', () {
    Future<void> pumpCard(WidgetTester tester, DirectoryContact contact) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DirectoryContactCard(contact: contact, onTap: () {})),
        ),
      );
    }

    testWidgets('shows All Categories for a buyer with none saved', (tester) async {
      await pumpCard(tester, _contact());
      expect(find.text('Interested in: All Categories'), findsOneWidget);
    });

    testWidgets('names the saved categories', (tester) async {
      await pumpCard(tester, _contact(categories: const [_grains, _oilseeds]));
      expect(find.text('Interested in: Grains & Cereals, Oilseeds'), findsOneWidget);
    });

    testWidgets('shows no interest line for a seller', (tester) async {
      await pumpCard(tester, _contact(role: ContactRole.seller));
      expect(find.textContaining('Interested in:'), findsNothing);
    });
  });
}
