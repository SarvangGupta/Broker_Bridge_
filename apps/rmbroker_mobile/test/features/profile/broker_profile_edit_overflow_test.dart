import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/profile/data/profile_repository.dart';
import 'package:rmbroker_mobile/features/profile/domain/broker_profile.dart';
import 'package:rmbroker_mobile/features/profile/presentation/broker_profile_screen.dart';

const _longName =
    'SHRI RADHA KRISHNA AGRICULTURAL COMMODITIES AND MANDI TRADING PRIVATE LIMITED COMPANY';
const _longAddress =
    'Shop No. 15-16, Krishi Upaj Mandi Samiti Yard, Near Old Railway Crossing, Surajpole Bazaar, Jaipur';

const _sizes = <String, Size>{
  '320x568': Size(320, 568),
  '360x640': Size(360, 640),
  '393x852': Size(393, 852),
  '800x1280': Size(800, 1280),
};

void main() {
  late SecureStorageService storage;

  setUp(() async {
    storage = SecureStorageService();
    storage.enableMemoryFallbackForTesting();
    await storage.clearAll();
    await storage.saveUserInfo(
      id: 'broker-test-202',
      role: 'broker',
      email: 'mukesh@sharmatrading.in',
      fullName: 'Mukesh Sharma',
    );
  });

  Future<void> openEditForm(
    WidgetTester tester,
    Size size, {
    required String businessType,
    required String state,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = ProfileRepository(storage: storage, localOnlyForTesting: true);
    final base =
        ((await repo.getProfile()) as ProfileSuccess<BrokerProfile>).data;
    await repo.updateProfile(
      base.copyWith(
        fullName: _longName,
        legalName: _longName,
        tradeName: _longName,
        businessType: businessType,
        constitution: businessType,
        principalPlaceOfBusiness: _longAddress,
        businessAddress: _longAddress,
        city: 'Sawai Madhopur Gangapur City Tehsil',
        state: state,
        pincode: '302003',
        operatingLocations:
            '$_longName, Jaipur Mandi, Krishi Upaj Mandi Samiti Sawai Madhopur',
        commoditiesHandled: '$_longName, Mustard Seed (Sarson)',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const BrokerProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Only the edit form is under test; discard anything the read-only view
    // reported on its way in.
    tester.takeException();
    await tester.tap(find.byTooltip('Edit Profile'));
    await tester.pumpAndSettle();
  }

  /// Every RenderFlex overflow surfaces as a test exception, so walking the
  /// whole scroll extent proves both the visible and the lower sections.
  Future<void> expectNoOverflowOverWholePage(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    final list = find.byType(Scrollable).first;
    for (var i = 0; i < 40; i++) {
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Commodities Handled'), findsOneWidget);
  }

  group('Edit Profile has no overflow', () {
    for (final entry in _sizes.entries) {
      for (final type in const [
        'Proprietorship',
        'Limited Liability Partnership (LLP)',
      ]) {
        testWidgets('${entry.key} with long values and "$type"', (
          tester,
        ) async {
          await openEditForm(
            tester,
            entry.value,
            businessType: type,
            state: 'Madhya Pradesh',
          );
          await expectNoOverflowOverWholePage(tester);
        });
      }

      testWidgets('${entry.key} at 1.3x text scale', (tester) async {
        await openEditForm(
          tester,
          entry.value,
          businessType: 'Limited Liability Partnership (LLP)',
          state: 'Madhya Pradesh',
          textScale: 1.3,
        );
        await expectNoOverflowOverWholePage(tester);
      });
    }
  });

  group('Edit Profile responsive layout', () {
    double dxOf(WidgetTester tester, String label) =>
        tester.getTopLeft(find.text(label)).dx;
    double dyOf(WidgetTester tester, String label) =>
        tester.getTopLeft(find.text(label)).dy;

    testWidgets('narrow screens stack Business Type above Registration Date', (
      tester,
    ) async {
      await openEditForm(
        tester,
        const Size(320, 568),
        businessType: 'Limited Liability Partnership (LLP)',
        state: 'Madhya Pradesh',
      );
      expect(
        dxOf(tester, 'Business Type'),
        dxOf(tester, 'Registration Date'),
      );
      expect(
        dyOf(tester, 'Business Type'),
        lessThan(dyOf(tester, 'Registration Date')),
      );
    });

    testWidgets('wide screens use side by side columns', (tester) async {
      await openEditForm(
        tester,
        const Size(800, 1280),
        businessType: 'Proprietorship',
        state: 'Madhya Pradesh',
      );
      expect(dyOf(tester, 'Business Type'), dyOf(tester, 'Registration Date'));
      expect(dyOf(tester, 'City *'), dyOf(tester, 'State *'));
      expect(dyOf(tester, 'City *'), dyOf(tester, 'PIN Code *'));
      expect(
        dxOf(tester, 'City *'),
        lessThan(dxOf(tester, 'State *')),
      );
    });

    testWidgets('GST certificate button spans the card width', (tester) async {
      await openEditForm(
        tester,
        const Size(320, 568),
        businessType: 'Proprietorship',
        state: 'Rajasthan',
      );
      final button = find.ancestor(
        of: find.text('Re-upload / Update GST Certificate'),
        matching: find.byWidgetPredicate((w) => w is OutlinedButton),
      );
      // 320 - list padding 32 - card padding 32 - card border 2.
      expect(tester.getSize(button).width, 254);
    });

    testWidgets('values, dropdown selection and save survive the layout', (
      tester,
    ) async {
      await openEditForm(
        tester,
        const Size(320, 568),
        businessType: 'Proprietorship',
        state: 'Rajasthan',
      );

      expect(find.text('Proprietorship'), findsOneWidget);
      expect(find.text('Rajasthan'), findsOneWidget);
      expect(find.text(_longAddress), findsOneWidget);

      await tester.ensureVisible(find.text('Rajasthan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rajasthan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Madhya Pradesh').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Madhya Pradesh'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      // Saving returns to the read-only view, which is not under test here.
      tester.takeException();

      final saved = (await ProfileRepository(storage: storage, localOnlyForTesting: true).getProfile())
          as ProfileSuccess<BrokerProfile>;
      expect(saved.data.state, 'Madhya Pradesh');
      expect(saved.data.legalName, _longName);
    });
  });
}
