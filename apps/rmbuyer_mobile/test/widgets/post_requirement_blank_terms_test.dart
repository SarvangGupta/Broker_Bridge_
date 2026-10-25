import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/requirements/presentation/post_requirement_screen.dart';

import '../support/fake_requirements_repository.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeRequirementsRepository repo, {
  required bool blank,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: PostRequirementScreen(
        repository: repo,
        initialCommodity: 'Maize DDGS',
        blankCommercialTerms: blank,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Text of the TextField whose hint is [hint] (the hint renders inside it).
String _fieldText(WidgetTester tester, String hint) {
  final field = tester.widget<TextField>(
    find.ancestor(of: find.text(hint), matching: find.byType(TextField)),
  );
  return field.controller!.text;
}

Future<void> _submit(WidgetTester tester) async {
  final submit = find.text('Submit Procurement Requirement');
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Nutrition Guide entry prefills only the material; commercial terms start blank',
    (tester) async {
      final repo = FakeRequirementsRepository();
      await _pump(tester, repo, blank: true);

      expect(
        find.descendant(
          of: find.byKey(const Key('commodity-picker-field')),
          matching: find.text('Maize DDGS'),
        ),
        findsOneWidget,
      );
      expect(_fieldText(tester, 'e.g. 100'), isEmpty);
      expect(_fieldText(tester, 'e.g. 4850'), isEmpty);
      expect(find.text('Select delivery location'), findsOneWidget);
      expect(find.text('Select delivery date'), findsOneWidget);
      expect(find.text('Select payment terms'), findsOneWidget);

      // Submitting blank is blocked by validation; nothing reaches the repository.
      await _submit(tester);
      expect(repo.submitted, isEmpty);
    },
  );

  testWidgets(
    'default entry keeps its existing defaults (unchanged behaviour)',
    (tester) async {
      await _pump(tester, FakeRequirementsRepository(), blank: false);

      expect(find.text('50'), findsOneWidget);
      expect(find.text('4800'), findsOneWidget);
      expect(find.text('Select delivery date'), findsNothing);
      expect(find.text('Select payment terms'), findsNothing);
    },
  );
}
