import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/core/widgets/app_button.dart';
import 'package:rmbuyer_mobile/core/widgets/app_error_state.dart';
import 'package:rmbuyer_mobile/features/requirements/data/requirements_repository.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_model.dart';
import 'package:rmbuyer_mobile/features/requirements/domain/requirement_timeline_event.dart';
import 'package:rmbuyer_mobile/features/requirements/presentation/requirement_details_screen.dart';

/// Offline fake: never touches Supabase. Each load pops the next scripted
/// result (a requirement, null, or an Exception to throw).
class _FakeRepo extends RequirementsRepository {
  _FakeRepo(this.results);

  final List<Object?> results;
  int loads = 0;
  Completer<void>? gate;

  @override
  Future<BuyerRequirement?> getRequirementById(String id) async {
    if (gate != null) await gate!.future;
    final r = results[loads < results.length ? loads : results.length - 1];
    loads++;
    if (r is Exception) throw r;
    return r as BuyerRequirement?;
  }

  @override
  Future<List<RequirementTimelineEvent>> getTimelineEvents(String requirementId) async => [];
}

BuyerRequirement _req({
  String commodity = 'Yellow Soybean',
  String grade = 'Grade A FAQ',
  double quantity = 50,
  double price = 4850,
}) =>
    BuyerRequirement(
      id: 'REQ-OVERFLOW-1',
      commodityName: commodity,
      gradeName: grade,
      quantity: quantity,
      unit: 'MT',
      targetPrice: price,
      status: 'Open',
      targetDate: DateTime(2026, 12, 1),
    );

Future<void> _pump(
  WidgetTester tester,
  RequirementsRepository repo, {
  Size size = const Size(320, 640),
  double textScale = 1.0,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: RequirementDetailsScreen(requirementId: 'REQ-OVERFLOW-1', repository: repo),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

const _longCommodity = 'Non-GMO Yellow Soybean Seeds (Bold, Machine Cleaned, Export Quality)';
const _longGrade = 'Grade A FAQ — Moisture max 10%, Foreign matter max 1%, Damaged max 2%';

void main() {
  group('RMBUYER-MANDATE-DETAILS-OVERFLOW-01', () {
    testWidgets('long commodity and grade wrap without overflow on 320dp phone', (tester) async {
      await _pump(tester, _FakeRepo([_req(commodity: _longCommodity, grade: _longGrade, quantity: 12500.5, price: 987654)]));

      expect(tester.takeException(), isNull);
      expect(find.text(_longCommodity), findsOneWidget);
      expect(find.text(_longGrade), findsOneWidget);
      expect(find.text('Est. Mandate Value'), findsOneWidget);

      // On a narrow screen Commodity and Grade stack vertically.
      final commodityTop = tester.getTopLeft(find.text('Commodity'));
      final gradeTop = tester.getTopLeft(find.text('Quality Grade'));
      expect(gradeTop.dy, greaterThan(commodityTop.dy));
      expect(gradeTop.dx, commodityTop.dx);
    });

    testWidgets('large text scale (2.0) renders without overflow', (tester) async {
      await _pump(
        tester,
        _FakeRepo([_req(commodity: _longCommodity, grade: _longGrade)]),
        size: const Size(360, 780),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(_longCommodity), findsOneWidget);
    });

    testWidgets('wide screen keeps commodity and grade side by side', (tester) async {
      await _pump(tester, _FakeRepo([_req()]), size: const Size(800, 1000));
      expect(tester.takeException(), isNull);
      final commodityTop = tester.getTopLeft(find.text('Commodity'));
      final gradeTop = tester.getTopLeft(find.text('Quality Grade'));
      expect(gradeTop.dy, commodityTop.dy);
      expect(gradeTop.dx, greaterThan(commodityTop.dx));
    });

    testWidgets('missing grade and optional fields show a dash, no crash', (tester) async {
      await _pump(tester, _FakeRepo([_req(grade: '  ')]));
      expect(tester.takeException(), isNull);
      expect(find.text('Quality Grade'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('Delivery Location / Terms'), findsNothing);
      expect(find.text('Packaging Type'), findsNothing);
    });

    testWidgets('loading state then populated state', (tester) async {
      final repo = _FakeRepo([_req()])..gate = Completer<void>();
      await _pump(tester, repo, settle: false);
      expect(find.textContaining('Loading verified requirement details'), findsOneWidget);

      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Mandate: REQ-OVERFLOW-1'), findsOneWidget);
      expect(find.text('Yellow Soybean'), findsOneWidget);
    });

    testWidgets('error state with working Retry', (tester) async {
      final repo = _FakeRepo([Exception('network down'), _req()]);
      await _pump(tester, repo);
      expect(find.textContaining('Failed to load requirement details'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(AppErrorState), matching: find.byType(AppButton)));
      await tester.pumpAndSettle();
      expect(repo.loads, 2);
      expect(find.text('Yellow Soybean'), findsOneWidget);
    });

    testWidgets('not-found shows empty state instead of a blank screen', (tester) async {
      await _pump(tester, _FakeRepo([null]));
      expect(find.text('Requirement Not Found'), findsOneWidget);
    });

    testWidgets('Refresh reloads the same requirement ID', (tester) async {
      final repo = _FakeRepo([_req(), _req(commodity: 'Sharbati Wheat')]);
      await _pump(tester, repo);
      expect(find.text('Yellow Soybean'), findsOneWidget);

      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(repo.loads, 2);
      expect(find.text('Sharbati Wheat'), findsOneWidget);
    });

    testWidgets('Back pops to the previous route', (tester) async {
      final repo = _FakeRepo([_req()]);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home')),
            routes: [
              GoRoute(
                path: 'details',
                builder: (_, _) =>
                    RequirementDetailsScreen(requirementId: 'REQ-OVERFLOW-1', repository: repo),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router));
      router.push('/details');
      await tester.pumpAndSettle();
      expect(find.text('Mandate: REQ-OVERFLOW-1'), findsOneWidget);

      await tester.tap(find.byType(IconButton).first); // AppBar leading back
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
