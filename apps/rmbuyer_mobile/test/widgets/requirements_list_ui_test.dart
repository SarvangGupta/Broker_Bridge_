import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/requirements/data/requirements_repository.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_model.dart';
import 'package:rmbuyer_mobile/features/requirements/presentation/requirements_screen.dart';

class _FakeRepo extends RequirementsRepository {
  final List<BuyerRequirement> items;
  _FakeRepo(this.items);

  @override
  Future<List<BuyerRequirement>> getRequirements({
    String? statusFilter,
    bool includeBaseline = true,
  }) async =>
      items;
}

BuyerRequirement _req(String id, String commodity, String status, int dayOffset,
    {bool hasDate = true}) {
  final now = DateTime.now();
  return BuyerRequirement(
    id: id,
    commodityName: commodity,
    gradeName: 'Std',
    quantity: 50,
    unit: 'MT',
    targetPrice: 42000,
    status: status,
    targetDate: DateTime(now.year, now.month, now.day + dayOffset),
    hasTargetDate: hasDate,
    deliveryTerms: 'Indore Mandi, Madhya Pradesh',
  );
}

void main() {
  final items = [
    _req('REQ-OVERDUE', 'Wheat', 'Open', -3),
    _req('REQ-DONE', 'Chana', 'Fulfilled', -10),
    _req('REQ-SOON', 'Soybean', 'In Negotiation', 5),
    _req('REQ-LATER', 'Yellow Maize', 'Open', 20),
    _req('REQ-NODATE', 'Mustard', 'Open', 0, hasDate: false),
  ];

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: RequirementsScreen(repository: _FakeRepo(items)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('groups by delivery date with badges and no overflow', (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('Overdue (1)'), findsOneWidget);
    expect(find.text('Due in 7 Days (1)'), findsOneWidget);
    expect(find.text('Overdue by 3 days'), findsOneWidget);
    expect(find.text('Due in 5 days'), findsOneWidget);

    // Completed past deadline is not marked overdue
    expect(find.text('Overdue by 10 days'), findsNothing);

    await tester.scrollUntilVisible(find.text('Date Not Set (1)'), 200,
        scrollable: find
            .descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable))
            .first);
    expect(find.text('Upcoming (2)'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('summary card filters by status and sections collapse', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('req-summary-inNegotiation')));
    await tester.pumpAndSettle();
    expect(find.text('Soybean'), findsOneWidget);
    expect(find.text('Wheat'), findsNothing);
    expect(find.byKey(const Key('req-clear-filters')), findsOneWidget);

    await tester.tap(find.byKey(const Key('req-clear-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Wheat'), findsOneWidget);

    await tester.tap(find.byKey(const Key('req-group-overdue')));
    await tester.pumpAndSettle();
    expect(find.text('Wheat'), findsNothing);
    expect(find.text('Overdue (1)'), findsOneWidget);
  });

  testWidgets('search with no results offers clear filters', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matching requirements'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'REQ-SOON');
    await tester.pumpAndSettle();
    expect(find.text('Soybean'), findsOneWidget);

    await tester.tap(find.text('Soybean'));
    await tester.pumpAndSettle();
    expect(find.text('View Timeline & Full Details'), findsOneWidget);
  });
}
