import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/profile/data/profile_repository.dart';
import 'package:rmbroker_mobile/features/profile/domain/broker_profile.dart';
import 'package:rmbroker_mobile/features/profile/presentation/broker_profile_screen.dart';

const _userId = 'broker-test-202';

/// Scripted repository for driving the screen's save states.
class _ScriptedRepo extends ProfileRepository {
  _ScriptedRepo(SecureStorageService storage)
      : super(storage: storage, localOnlyForTesting: true);

  int updateCalls = 0;
  Completer<ProfileResult<BrokerProfile>>? next;

  @override
  Future<ProfileResult<BrokerProfile>> updateProfile(BrokerProfile updated) {
    updateCalls++;
    final pending = next;
    return pending != null ? pending.future : super.updateProfile(updated);
  }
}

void main() {
  late SecureStorageService storage;

  setUp(() async {
    storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
    await storage.saveUserInfo(
      id: _userId,
      role: 'broker',
      email: 'mukesh@sharmatrading.in',
      fullName: 'Mukesh Sharma',
    );
  });

  group('Save Changes on the Edit Profile screen', () {
    final saveButton = find.byKey(const ValueKey('edit_profile_save_changes'));

    Future<_ScriptedRepo> open(
      WidgetTester tester, {
      Size size = const Size(320, 568),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _ScriptedRepo(storage);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [profileRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: BrokerProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Profile'));
      await tester.pumpAndSettle();
      // Only the edit form is under test here.
      tester.takeException();
      return repo;
    }

    Finder fieldLabelled(String label) => find.descendant(
          of: find.ancestor(
            of: find.text(label),
            matching: find.byType(Column),
          ).first,
          matching: find.byType(TextFormField),
        );

    Future<void> enter(WidgetTester tester, String label, String text) async {
      await tester.ensureVisible(fieldLabelled(label));
      await tester.pumpAndSettle();
      await tester.enterText(fieldLabelled(label), text);
      await tester.pump();
    }

    testWidgets('sits below the scrolling form, not over it', (tester) async {
      await open(tester);
      final list = find.byType(ListView);
      expect(saveButton, findsOneWidget);
      expect(
        tester.getBottomLeft(list).dy,
        lessThanOrEqualTo(tester.getTopLeft(saveButton).dy),
      );
      expect(tester.getBottomLeft(saveButton).dy, lessThanOrEqualTo(568));
      expect(tester.getSize(saveButton).width, 320 - 32);

      // The last section can scroll fully clear of the bar.
      await tester.drag(list, const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.text('Add Commodity')).dy,
        lessThan(tester.getTopLeft(saveButton).dy),
      );
    });

    testWidgets('is not shown in the read-only view', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      tester.takeException();
      expect(saveButton, findsNothing);
    });

    testWidgets('no edits: says so and does not call the repository', (
      tester,
    ) async {
      final repo = await open(tester);
      await tester.tap(saveButton);
      await tester.pump();
      expect(find.text('No changes to save'), findsOneWidget);
      expect(repo.updateCalls, 0);
    });

    testWidgets('invalid fields show errors and reveal the first one', (
      tester,
    ) async {
      final repo = await open(tester);
      await enter(tester, 'PIN Code *', '12');
      await enter(tester, 'Legal Business Name *', '   ');

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repo.updateCalls, 0);
      expect(find.text('Enter a 6-digit PIN code'), findsOneWidget);
      final error = find.text('Legal business name is required');
      expect(error, findsOneWidget);
      // Visible between the app bar and the Save Changes bar.
      final y = tester.getTopLeft(error).dy;
      expect(y, greaterThan(tester.getBottomLeft(find.byType(AppBar)).dy));
      expect(y, lessThan(tester.getTopLeft(saveButton).dy));
    });

    testWidgets('failure keeps the form and the entered values', (
      tester,
    ) async {
      final repo = await open(tester);
      repo.next = Completer()
        ..complete(const ProfileError(message: 'Could not reach the server.'));
      await enter(tester, 'City *', 'Sikar');

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Could not reach the server.'), findsWidgets);
      expect(find.text('Profile updated successfully'), findsNothing);
      expect(saveButton, findsOneWidget);
      expect(find.text('Sikar'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('session expiry keeps the values and offers sign in', (
      tester,
    ) async {
      final repo = await open(tester);
      repo.next = Completer()..complete(const ProfileUnauthorized());
      await enter(tester, 'City *', 'Sikar');

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Sikar'), findsOneWidget);
    });

    testWidgets('repeated taps submit once and show a loading state', (
      tester,
    ) async {
      final repo = await open(tester);
      final pending = Completer<ProfileResult<BrokerProfile>>();
      repo.next = pending;
      await enter(tester, 'City *', 'Sikar');

      await tester.tap(saveButton);
      await tester.pump();
      await tester.tap(saveButton, warnIfMissed: false);
      await tester.pump();

      expect(repo.updateCalls, 1);
      expect(find.text('Saving...'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(saveButton).onPressed,
        isNull,
      );

      pending.complete(const ProfileError(message: 'nope'));
      await tester.pumpAndSettle();
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('success confirms, leaves edit mode, and reopens with values', (
      tester,
    ) async {
      await open(tester);
      await enter(tester, 'Legal Business Name *', 'NEW LEGAL NAME');
      await enter(tester, 'Trade Name', 'New Trade');
      await enter(tester, 'Principal Place of Business *', 'New Address');
      await enter(tester, 'City *', 'Sikar');
      await enter(tester, 'PIN Code *', '332001');

      await tester.ensureVisible(find.text('Add Mandi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Mandi'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Sikar Mandi');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('Profile updated successfully'), findsOneWidget);
      expect(saveButton, findsNothing);

      // Leave the screen entirely and come back to a fresh load.
      await tester.pumpWidget(const SizedBox());
      await open(tester);

      expect(find.text('NEW LEGAL NAME'), findsOneWidget);
      expect(find.text('New Address'), findsOneWidget);
      expect(find.text('Sikar'), findsOneWidget);
      expect(find.text('332001'), findsOneWidget);
      expect(find.text('Sikar Mandi'), findsOneWidget);

      // Reloaded values are the new baseline.
      await tester.tap(saveButton);
      await tester.pump();
      expect(find.text('No changes to save'), findsOneWidget);
    });
  });
}
