import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/app/theme/app_theme.dart';
import 'package:rmbuyer_mobile/features/profile/domain/buyer_profile.dart';
import 'package:rmbuyer_mobile/features/profile/presentation/buyer_profile_screen.dart';

import '../support/fake_buyer_profile_repository.dart';

Future<void> _pump(WidgetTester tester, FakeBuyerProfileRepository repo) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: BuyerProfileScreen(repository: repo),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _field(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('profile-save')));
  await tester.tap(find.byKey(const Key('profile-save')));
  await tester.pump();
}

void main() {
  testWidgets('loads the stored profile; only name and mobile are editable', (
    tester,
  ) async {
    await _pump(tester, FakeBuyerProfileRepository());

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(_field(tester, 'profile-name-field'), 'Rajesh Singhal');
    expect(_field(tester, 'profile-mobile-field'), '+919876543210');

    // Exactly two editable fields; email, company, GSTIN, verification and role are text only.
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('buyer@apexprocurement.com'), findsOneWidget);
    expect(find.text('Apex Grain Processors Pvt Ltd'), findsOneWidget);
    expect(find.text('08AABCA1234F1Z8'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-verification')),
        matching: find.text('Not verified'),
      ),
      findsOneWidget,
    );
    expect(find.text('Buyer'), findsOneWidget);
    // The old hardcoded badge and trust score are gone.
    expect(find.text('GST VERIFIED'), findsNothing);
    expect(find.textContaining('98 / 100'), findsNothing);
  });

  testWidgets('missing values show "Not provided" instead of placeholders', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeBuyerProfileRepository(
        profile: const BuyerProfile(id: 'b-2', name: 'Asha', role: 'buyer'),
      ),
    );
    expect(
      find.text('Not provided'),
      findsNWidgets(4),
    ); // email, company, GSTIN, verification
    expect(find.text('Apex Grain Processors Pvt Ltd'), findsNothing);
  });

  testWidgets(
    'invalid name and mobile are rejected with field messages and nothing is saved',
    (tester) async {
      final repo = FakeBuyerProfileRepository();
      await _pump(tester, repo);

      await tester.enterText(find.byKey(const Key('profile-name-field')), ' ');
      await tester.enterText(
        find.byKey(const Key('profile-mobile-field')),
        '12345',
      );
      await _save(tester);
      await tester.pumpAndSettle();

      expect(find.text('Enter your name.'), findsOneWidget);
      expect(
        find.text('Enter a valid 10-digit Indian mobile number.'),
        findsOneWidget,
      );
      expect(repo.writes, isEmpty);

      await tester.enterText(find.byKey(const Key('profile-name-field')), 'A');
      await _save(tester);
      await tester.pumpAndSettle();
      expect(find.text('Name must be 2 to 80 characters.'), findsOneWidget);
      expect(repo.writes, isEmpty);
    },
  );

  testWidgets(
    'saving sends only changed fields and the values persist on reopen',
    (tester) async {
      final repo = FakeBuyerProfileRepository();
      await _pump(tester, repo);

      await tester.enterText(
        find.byKey(const Key('profile-mobile-field')),
        '98290 12345',
      );
      await _save(tester);
      await tester.pumpAndSettle();

      expect(repo.writes, [
        {'mobile': '+919829012345'},
      ]);
      expect(find.text('Profile saved.'), findsOneWidget);
      expect(_field(tester, 'profile-mobile-field'), '+919829012345');

      // Reopen: a fresh screen loads what was stored; the name was untouched.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, repo);
      expect(_field(tester, 'profile-mobile-field'), '+919829012345');
      expect(_field(tester, 'profile-name-field'), 'Rajesh Singhal');
    },
  );

  testWidgets('no changes means no request', (tester) async {
    final repo = FakeBuyerProfileRepository();
    await _pump(tester, repo);
    await _save(tester);
    await tester.pumpAndSettle();
    expect(repo.writes, isEmpty);
    expect(find.text('No changes to save.'), findsOneWidget);
  });

  testWidgets(
    'a failed save shows an error, keeps the typed text and never shows success',
    (tester) async {
      final repo = FakeBuyerProfileRepository()
        ..saveError = Exception('RLS denied');
      await _pump(tester, repo);

      await tester.enterText(
        find.byKey(const Key('profile-name-field')),
        'Rajesh K Singhal',
      );
      await _save(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile-save-error')), findsOneWidget);
      expect(find.text('Profile saved.'), findsNothing);
      expect(_field(tester, 'profile-name-field'), 'Rajesh K Singhal');
      expect(repo.stored.name, 'Rajesh Singhal');
    },
  );

  testWidgets('a second tap while saving does not send a second request', (
    tester,
  ) async {
    final repo = FakeBuyerProfileRepository()..saveGate = Completer<void>();
    await _pump(tester, repo);

    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      'Rajesh K Singhal',
    );
    await _save(tester);
    await _save(tester);
    expect(repo.writes, hasLength(1));

    repo.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Profile saved.'), findsOneWidget);
  });

  testWidgets(
    'load failure shows an error with retry and no placeholder profile',
    (tester) async {
      final repo = FakeBuyerProfileRepository()
        ..loadError = Exception('offline');
      await _pump(tester, repo);

      expect(
        find.textContaining('Could not load your profile'),
        findsOneWidget,
      );
      expect(find.byType(TextFormField), findsNothing);

      repo.loadError = null;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(_field(tester, 'profile-name-field'), 'Rajesh Singhal');
    },
  );
}
