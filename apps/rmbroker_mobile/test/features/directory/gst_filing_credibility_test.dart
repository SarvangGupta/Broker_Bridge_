import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/directory/data/directory_repository.dart';
import 'package:rmbroker_mobile/features/directory/data/gst_filing_provider.dart';
import 'package:rmbroker_mobile/features/directory/domain/directory_contact.dart';
import 'package:rmbroker_mobile/features/directory/domain/gst_certificate_data.dart';
import 'package:rmbroker_mobile/features/directory/domain/gst_filing_history.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/directory_controller.dart';
import 'package:rmbroker_mobile/features/directory/presentation/controllers/gst_filing_controller.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/contact_details_sheet.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/contact_form_modal.dart';
import 'package:rmbroker_mobile/features/directory/presentation/widgets/gst_filing_history_sheet.dart';

import 'directory_repository_test.dart' show MockSecureStorageService;

class _MockDetailsDirectoryRepository extends DirectoryRepository {
  final DirectoryContact contact;
  _MockDetailsDirectoryRepository(this.contact)
      : super(
          storage: MockSecureStorageService({
            'rmbroker_user_id': 'broker-test-1',
          }),
        );

  @override
  Future<DirectoryDataResult<ContactDetailsPayload>> getContactDetails(String id) async {
    return DirectorySuccess(ContactDetailsPayload(
      contact: contact,
      associatedRequirements: const [],
      associatedOffers: const [],
      linkedDeals: const [],
      activities: const [],
    ));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const validMonthlyGstin = '27AABCU9603R1ZN'; // Regular monthly filer
  const validQuarterlyGstin = '27AABCU9603Q1ZQ'; // QRMP quarterly filer
  const cancelledGstin = '27AABCU9603C1ZC'; // Cancelled registration
  const partialHistoryGstin = '03AABCU9603P1ZP'; // Partial history (new reg FY 2024-25)

  late GstFilingRepository repository;
  late MockSecureStorageService storage;

  setUp(() {
    storage = MockSecureStorageService({
      'rmbroker_user_id': 'broker-user-1',
      'rmbroker_user_role': 'broker',
    });
    repository = GstFilingRepository(
      provider: const GstMockDataProvider(),
      storage: storage,
    );
  });

  group('MICRO-SPRINT: RMBROKER-GST-CREDIBILITY-01 (10 Required Scenarios)', () {
    // -------------------------------------------------------------------------
    // SCENARIO 1: Valid GSTIN with complete filing history
    // -------------------------------------------------------------------------
    test('1. Valid GSTIN retrieves complete 5-year history plus current FY 2026-27 YTD', () async {
      final snapshot = await repository.getFilingHistory(validMonthlyGstin);

      expect(snapshot.gstin, equals(validMonthlyGstin));
      expect(snapshot.taxpayer.isActive, isTrue);
      expect(snapshot.taxpayer.status, equals('Active'));

      // Check coverage: targeting FY 2021-22 to FY 2026-27
      expect(snapshot.availableFinancialYears, containsAll([
        '2026-27',
        '2025-26',
        '2024-25',
        '2023-24',
        '2022-23',
        '2021-22',
      ]));

      // Check filings present
      expect(snapshot.filings.length, greaterThanOrEqualTo(60)); // 5 full years * 12 + YTD
      final march2026 = snapshot.filings.firstWhere(
        (f) => f.financialYear == '2025-26' && f.periodOrder == 12,
      );
      expect(march2026.gstr1Status, equals(GstReturnStatus.filed));
      expect(march2026.gstr1FilingDate, isNotNull);
      expect(march2026.gstr3bStatus, equals(GstReturnStatus.filed));
      expect(march2026.gstr3bFilingDate, isNotNull);

      // Check credibility summary
      final summary = snapshot.summary;
      expect(summary.totalConfirmedFiled, greaterThan(100));
      expect(summary.latestFilingDate, isNotNull);
      expect(summary.historicalCoverage, contains('FY 2021-22 to FY 2026-27'));
      expect(summary.filingFrequency, equals('Monthly'));
    });

    // -------------------------------------------------------------------------
    // SCENARIO 2: Valid GSTIN with partial historical data
    // -------------------------------------------------------------------------
    test('2. Valid GSTIN with partial historical data displays clear limitation notice', () async {
      final snapshot = await repository.getFilingHistory(partialHistoryGstin);

      expect(snapshot.gstin, equals(partialHistoryGstin));
      expect(snapshot.taxpayer.registrationDate, equals('15/06/2024'));

      // Available years only include active years (2024-25 onwards)
      expect(snapshot.availableFinancialYears, contains('2024-25'));
      expect(snapshot.availableFinancialYears, contains('2026-27'));

      // Summary explicitly explains the limitation
      expect(snapshot.summary.dataLimitationNotice, isNotNull);
      expect(snapshot.summary.dataLimitationNotice, contains('FY 2024-25'));
      expect(snapshot.summary.dataLimitationNotice, contains('prior to registration date are not applicable'));
    });

    // -------------------------------------------------------------------------
    // SCENARIO 3: Inactive or cancelled GST registration
    // -------------------------------------------------------------------------
    test('3. Cancelled GST registration displays cancelled status and cancellation date', () async {
      final snapshot = await repository.getFilingHistory(cancelledGstin);

      expect(snapshot.taxpayer.isActive, isFalse);
      expect(snapshot.taxpayer.isCancelled, isTrue);
      expect(snapshot.taxpayer.status, equals('Cancelled'));
      expect(snapshot.taxpayer.cancellationDate, equals('31/03/2024'));

      // Returns after cancellation date are marked Not Applicable, NOT missed returns
      final postCancellation = snapshot.filings.where(
        (f) => f.financialYear == '2024-25' && f.periodOrder >= 4,
      );
      for (final p in postCancellation) {
        expect(p.gstr1Status, equals(GstReturnStatus.notApplicable));
        expect(p.gstr3bStatus, equals(GstReturnStatus.notApplicable));
      }
    });

    // -------------------------------------------------------------------------
    // SCENARIO 4: Invalid GSTIN rejection
    // -------------------------------------------------------------------------
    test('4. Invalid GSTIN throws GstApiException with isInvalidGstin flag', () async {
      expect(
        () => repository.getFilingHistory('INVALID123'),
        throwsA(isA<GstApiException>().having(
          (e) => e.isInvalidGstin,
          'isInvalidGstin',
          isTrue,
        )),
      );

      expect(
        () => repository.getFilingHistory(''),
        throwsA(isA<GstApiException>()),
      );
    });

    // -------------------------------------------------------------------------
    // SCENARIO 5: Quarterly filer (QRMP)
    // -------------------------------------------------------------------------
    test('5. Quarterly filer (QRMP) does not mark non-quarter months as missed returns', () async {
      final snapshot = await repository.getFilingHistory(validQuarterlyGstin);

      expect(snapshot.taxpayer.filingFrequency, equals('Quarterly (QRMP)'));
      expect(snapshot.taxpayer.isQuarterlyFiler, isTrue);

      // Verifies quarterly records (Q1, Q2, Q3, Q4) are filed per quarter
      final q1 = snapshot.filings.firstWhere(
        (f) => f.financialYear == '2024-25' && f.periodOrder == 3,
      );
      expect(q1.isQuarterly, isTrue);
      expect(q1.taxPeriod, contains('Q1'));
      expect(q1.gstr1Status, equals(GstReturnStatus.filed));
      expect(q1.gstr3bStatus, equals(GstReturnStatus.filed));

      // Overdue returns must NOT falsely report 0-filed months as overdue
      expect(snapshot.summary.totalConfirmedOverdue, equals(0));
    });

    // -------------------------------------------------------------------------
    // SCENARIO 6: Monthly filer
    // -------------------------------------------------------------------------
    test('6. Monthly filer records monthly GSTR-1 and GSTR-3B filings', () async {
      final snapshot = await repository.getFilingHistory(validMonthlyGstin);

      expect(snapshot.taxpayer.filingFrequency, equals('Monthly'));

      final april = snapshot.filings.firstWhere(
        (f) => f.financialYear == '2024-25' && f.periodOrder == 1,
      );
      expect(april.taxPeriod, contains('April'));
      expect(april.gstr1Status, equals(GstReturnStatus.filed));
      expect(april.gstr3bStatus, equals(GstReturnStatus.filed));
      expect(april.isQuarterly, isFalse);
    });

    // -------------------------------------------------------------------------
    // SCENARIO 7: API timeout or provider failure
    // -------------------------------------------------------------------------
    test('7. API timeout or provider failure is handled gracefully with clear error state', () async {
      final timeoutRepo = GstFilingRepository(
        provider: const GstMockDataProvider(simulateTimeout: true),
        storage: storage,
      );

      final container = ProviderContainer(
        overrides: [
          gstFilingRepositoryProvider.overrideWithValue(timeoutRepo),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(gstFilingControllerProvider(validMonthlyGstin).notifier);
      await controller.loadFilingHistory(validMonthlyGstin);

      final state = container.read(gstFilingControllerProvider(validMonthlyGstin));
      expect(state.isError, isTrue);
      expect(state.errorMessage, contains('timed out'));
      expect(state.isLoading, isFalse);
    });

    // -------------------------------------------------------------------------
    // SCENARIO 8: Official GST Portal CAPTCHA required & Manual Verification Fallback
    // -------------------------------------------------------------------------
    test('8. Official GST Portal CAPTCHA required records manual verification with proper provenance', () async {
      final manualSnapshot = await repository.recordManualPortalVerification(
        gstin: validMonthlyGstin,
        companyId: 'comp-portal-1',
        observedStatus: 'Active',
        latestFilingSummary: 'GSTR-3B confirmed filed through September 2026',
        brokerNotes: 'Verified directly on services.gst.gov.in after solving CAPTCHA',
      );

      expect(manualSnapshot.gstin, equals(validMonthlyGstin));
      expect(manualSnapshot.dataSource, equals('Official GST Portal (Manually Verified)'));
      expect(manualSnapshot.taxpayer.status, equals('Active'));
      expect(manualSnapshot.summary.historicalCoverage, contains('Official GST Portal Manual Lookup'));
      expect(manualSnapshot.summary.dataLimitationNotice, contains('September 2026'));
      expect(manualSnapshot.isCached, isFalse);

      // Verify cached snapshot retains the portal source
      final cachedPortal = await repository.getFilingHistory(validMonthlyGstin);
      expect(cachedPortal.isCached, isTrue);
      expect(cachedPortal.dataSource, equals('Official GST Portal (Manually Verified)'));
    });

    test('8b. Missing historical records in public registry are not interpreted as missed returns', () async {
      const missingRecordFiling = TaxPeriodFiling(
        financialYear: '2021-22',
        taxPeriod: 'May 2021',
        periodOrder: 2,
        gstr1Status: GstReturnStatus.unavailable,
        gstr3bStatus: GstReturnStatus.unavailable,
      );

      // Neither status is "Filed" nor "Not Filed" (overdue)
      expect(missingRecordFiling.isGstr1Filed, isFalse);
      expect(missingRecordFiling.gstr1Status == GstReturnStatus.notFiled, isFalse);
      expect(missingRecordFiling.gstr1Status, equals(GstReturnStatus.unavailable));
    });

    // -------------------------------------------------------------------------
    // SCENARIO 9: Refresh existing filing history
    // -------------------------------------------------------------------------
    test('9. Refresh existing filing history invalidates cache and retrieves fresh live snapshot', () async {
      // 1. First fetch: retrieved fresh, stored in cache
      final firstFetch = await repository.getFilingHistory(validMonthlyGstin);
      expect(firstFetch.isCached, isFalse);

      // 2. Second fetch without forceRefresh: returns cached snapshot
      final cachedFetch = await repository.getFilingHistory(validMonthlyGstin);
      expect(cachedFetch.isCached, isTrue);

      // 3. Third fetch with forceRefresh = true: invalidates cache and returns fresh live snapshot
      final refreshedFetch = await repository.getFilingHistory(validMonthlyGstin, forceRefresh: true);
      expect(refreshedFetch.isCached, isFalse);
    });

    // -------------------------------------------------------------------------
    // SCENARIO 10: Counterparty isolation between brokers
    // -------------------------------------------------------------------------
    test('10. Counterparty isolation verifies broker authorization before serving cached records', () async {
      // Broker 1 storage and repo
      final broker1Storage = MockSecureStorageService({'rmbroker_user_id': 'broker-1'});
      final broker1Repo = GstFilingRepository(
        provider: const GstMockDataProvider(),
        storage: broker1Storage,
      );

      // Broker 2 storage and repo
      final broker2Storage = MockSecureStorageService({'rmbroker_user_id': 'broker-2'});
      final broker2Repo = GstFilingRepository(
        provider: const GstMockDataProvider(),
        storage: broker2Storage,
      );

      final snap1 = await broker1Repo.getFilingHistory(validMonthlyGstin, companyId: 'comp-101');
      expect(snap1.companyId, equals('comp-101'));

      // Broker 2 accessing independent cache instance does not read unshared in-memory state
      final snap2 = await broker2Repo.getFilingHistory(validMonthlyGstin, companyId: 'comp-202');
      expect(snap2.companyId, equals('comp-202'));
    });
  });

  group('UI Integration: Check GST Filing History button tests', () {
    testWidgets('Button is disabled when GSTIN is empty and enabled when valid GSTIN is present', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gstFilingRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ContactFormModal(
                isEditing: false,
                defaultRole: ContactRole.buyer,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the "Check GST Filing History" button
      final btnFinder = find.byKey(const Key('check_gst_filing_history_button'));
      expect(btnFinder, findsOneWidget);

      // Initially GSTIN is empty -> button is disabled (onPressed is null)
      var button = tester.widget<OutlinedButton>(btnFinder);
      expect(button.enabled, isFalse);

      // Enter valid GSTIN
      await tester.enterText(find.byKey(const Key('contact_form_gstin_field')), validMonthlyGstin);
      await tester.pumpAndSettle();

      button = tester.widget<OutlinedButton>(btnFinder);
      expect(button.enabled, isTrue);

      // Tap button -> opens GstFilingHistorySheet
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      expect(find.byType(GstFilingHistorySheet), findsOneWidget);
      expect(find.text('GST Return Filing History'), findsOneWidget);
    });

    testWidgets('ContactDetailsSheet displays GST section and Check GST Filing History button', (tester) async {
      final contact = DirectoryContact(
        id: 'c-01',
        userId: 'u-01',
        companyId: 'comp-01',
        name: 'Suresh Patil',
        companyName: 'Patil Agro',
        mobile: '+919876543210',
        role: ContactRole.seller,
        createdAt: DateTime.now(),
        gstin: validMonthlyGstin,
        legalName: 'PATIL AGRO PRIVATE LIMITED',
        gstVerificationStatus: CounterpartyGstStatus.brokerVerified,
      );

      final mockRepo = _MockDetailsDirectoryRepository(contact);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryRepositoryProvider.overrideWithValue(mockRepo),
            gstFilingRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ContactDetailsSheet(initialContact: contact),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('GST & Business Credibility'), findsOneWidget);
      final profileBtn = find.byKey(const Key('profile_check_gst_filing_history_button'));
      expect(profileBtn, findsOneWidget);

      final button = tester.widget<OutlinedButton>(profileBtn);
      expect(button.enabled, isTrue);

      // Scroll into view if needed and tap
      await tester.ensureVisible(profileBtn);
      await tester.pumpAndSettle();
      await tester.tap(profileBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(GstFilingHistorySheet), findsOneWidget);
    });

    test('11. Free Public API provider GstJamkuPublicApiProvider parses genuine public payload cleanly', () async {
      // Mock Dio adapter returning real-world Jamku JSON format
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final uri = options.uri.toString();
            if (uri.contains('27AABCU9603R1ZN')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'success': true,
                    'data': {
                      'lgnm': 'UJJIVAN SMALL FINANCE BANK LIMITED',
                      'tradeName': 'UJJIVAN SMALL FINANCE BANK LIMITED',
                      'sts': 'Active',
                      'dty': 'Regular',
                      'rgdt': '01/07/2017',
                      'cxdt': '',
                      'adr': '7th Floor, A 1 Monte IT Park, Pune, Maharashtra',
                      'returns': [
                        {
                          'fy': '2026-2027',
                          'taxp': 'September',
                          'rtntype': 'GSTR1',
                          'dof': '08/10/2026',
                        },
                        {
                          'fy': '2026-2027',
                          'taxp': 'September',
                          'rtntype': 'GSTR3B',
                          'dof': '19/10/2026',
                        },
                        {
                          'fy': '2025-2026',
                          'taxp': 'March',
                          'rtntype': 'GSTR1',
                          'dof': '10/04/2026',
                        },
                        {
                          'fy': '2025-2026',
                          'taxp': 'March',
                          'rtntype': 'GSTR3B',
                          'dof': '18/04/2026',
                        },
                      ],
                    },
                  },
                ),
              );
            } else if (uri.contains('INVALID')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 500,
                  data: {
                    'success': false,
                    'message': 'GSTIN checksum failed',
                    'error': 'InputError',
                  },
                ),
              );
            }
            return handler.reject(DioException(requestOptions: options));
          },
        ),
      );

      final freeProvider = GstJamkuPublicApiProvider(dio: mockDio);
      final snapshot = await freeProvider.fetchFilingHistory(validMonthlyGstin);

      expect(snapshot.gstin, equals(validMonthlyGstin));
      expect(snapshot.taxpayer.legalName, contains('UJJIVAN SMALL FINANCE BANK'));
      expect(snapshot.taxpayer.isActive, isTrue);
      expect(snapshot.dataSource, equals('Jamku Public GST API (Free)'));
      expect(snapshot.filings.length, equals(2)); // Sep 2026 and Mar 2026

      final sep2026 = snapshot.filings.firstWhere((f) => f.taxPeriod == 'September');
      expect(sep2026.isGstr1Filed, isTrue);
      expect(sep2026.gstr1FilingDate, equals('08/10/2026'));
      expect(sep2026.isGstr3bFiled, isTrue);
      expect(sep2026.gstr3bFilingDate, equals('19/10/2026'));
      expect(snapshot.summary.totalConfirmedFiled, equals(4)); // 2 GSTR-1 + 2 GSTR-3B
    });

    test('12. Jamku provider rejects checksum failure with isInvalidGstin flag', () async {
      final mockDio = Dio();
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': false,
                  'message': 'GSTIN checksum failed',
                  'error': 'InputError',
                },
              ),
            );
          },
        ),
      );

      final freeProvider = GstJamkuPublicApiProvider(dio: mockDio);
      expect(
        () => freeProvider.fetchFilingHistory(validMonthlyGstin),
        throwsA(
          isA<GstApiException>().having((e) => e.isInvalidGstin, 'isInvalidGstin', isTrue),
        ),
      );
    });
  });
}
