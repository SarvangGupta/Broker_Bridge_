import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmbroker_mobile/features/dashboard/presentation/widgets/broker_desk_sheet.dart';
import 'package:rmbroker_mobile/features/search/presentation/widgets/quick_communication_sheet.dart';

// RB-BROKER-DESK-UI-01. No real contacts; url_launcher is intercepted.

void main() {
  final launched = <String>[];

  setUp(() {
    launched.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async {
        launched.add(call.arguments is Map ? (call.arguments as Map)['url'].toString() : '${call.arguments}');
        return true;
      },
    );
  });

  Future<void> pump(WidgetTester tester, {String support = '', Size size = const Size(1080, 2160), double dpr = 2.75}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => BrokerDeskSheet.show(ctx, supportWhatsApp: support),
                child: const Text('open desk'),
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.work), label: 'Work Desk'),
          ]),
        ),
      ),
      GoRoute(path: '/directory', builder: (_, _) => const Scaffold(body: Text('DIRECTORY SCREEN'))),
    ]);
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await tester.tap(find.text('open desk'));
    await tester.pumpAndSettle();
  }

  Finder card(String key) => find.byKey(ValueKey('broker_desk_$key'));

  testWidgets('opens with short title, six cards in grid order, no long description; closes', (tester) async {
    await pump(tester);
    expect(find.text('Broker Desk'), findsOneWidget);
    expect(find.textContaining('coordination line'), findsNothing);

    final order = ['call', 'whatsapp', 'directory', 'mandi_support', 'chat', 'info'];
    final centers = [for (final k in order) tester.getCenter(card(k))];
    for (var i = 0; i < 6; i += 2) {
      expect(centers[i].dy, moreOrLessEquals(centers[i + 1].dy), reason: 'row ${i ~/ 2 + 1} aligned');
      expect(centers[i].dx, lessThan(centers[i + 1].dx), reason: 'left before right');
      if (i > 0) expect(centers[i].dy, greaterThan(centers[i - 2].dy), reason: 'rows top to bottom');
    }
    for (final l in ['Call', 'WhatsApp', 'Directory', 'Mandi Support', 'Chat', 'Info']) {
      expect(find.bySemanticsLabel(l), findsOneWidget, reason: '$l accessible');
    }

    await tester.tap(find.byKey(const ValueKey('broker_desk_close')));
    await tester.pumpAndSettle();
    expect(find.text('Broker Desk'), findsNothing);
    expect(find.text('Home'), findsOneWidget, reason: 'bottom navigation untouched');
  });

  testWidgets('Call and WhatsApp open the existing authorized contact sheet', (tester) async {
    for (final k in ['call', 'whatsapp']) {
      // The existing contact sheet is laid out for wider test surfaces.
      await pump(tester, size: const Size(800, 1600), dpr: 1.0);
      await tester.tap(card(k));
      // The contact sheet keeps a loading spinner animating; pump fixed frames.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(QuickCommunicationSheet), findsOneWidget, reason: k);
      expect(find.text('Broker Desk'), findsNothing);
      Navigator.of(tester.element(find.byType(QuickCommunicationSheet))).pop();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }
  });

  testWidgets('Directory navigates to the existing Directory route', (tester) async {
    await pump(tester);
    await tester.tap(card('directory'));
    await tester.pumpAndSettle();
    expect(find.text('DIRECTORY SCREEN'), findsOneWidget);
  });

  testWidgets('Mandi Support without configuration reports it and launches nothing', (tester) async {
    await pump(tester);
    await tester.tap(card('mandi_support'));
    await tester.pumpAndSettle();
    expect(find.text('Mandi Support WhatsApp is not configured yet.'), findsOneWidget);
    expect(launched, isEmpty);
  });

  testWidgets('Mandi Support with a configured number opens that WhatsApp chat', (tester) async {
    await pump(tester, support: '9876500999');
    await tester.tap(card('mandi_support'));
    await tester.pumpAndSettle();
    expect(launched, hasLength(1));
    expect(launched.single, contains('wa.me/919876500999'));
  });

  testWidgets('Chat states it is unavailable; Info opens the minimal dialog', (tester) async {
    await pump(tester);
    await tester.tap(card('chat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('In-app chat is not available yet'), findsOneWidget);

    await tester.tap(find.text('open desk'));
    await tester.pumpAndSettle();
    await tester.tap(card('info'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Mandi Support: message the administrator'), findsOneWidget);
  });

  testWidgets('fits a small 320x568 screen without overflow', (tester) async {
    await pump(tester, size: const Size(640, 1136), dpr: 2.0);
    expect(tester.takeException(), isNull);
    expect(card('info').hitTestable(), findsOneWidget);
  });
}
