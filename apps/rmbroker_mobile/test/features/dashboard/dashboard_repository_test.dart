import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/network/api_client.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/dashboard/data/dashboard_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardRepository Tests', () {
    late SecureStorageService storage;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({
        'rmbroker_user_id': 'broker-uuid-1234',
        'rmbroker_user_role': 'broker',
        'rmbroker_user_email': 'nilesh.broker@jaipurmandi.com',
        'rmbroker_user_name': 'Nilesh Kumar',
      });
      storage = SecureStorageService();
    });

    test('getAuthenticatedBroker resolves stored broker identity', () async {
      final repository = DashboardRepository(storage: storage);
      final broker = await repository.getAuthenticatedBroker();

      expect(broker, isNotNull);
      expect(broker!.id, equals('broker-uuid-1234'));
      expect(broker.fullName, equals('Nilesh Kumar'));
      expect(broker.email, equals('nilesh.broker@jaipurmandi.com'));
      expect(broker.role, equals('broker'));
      expect(broker.isBrokerOrAdmin, isTrue);
    });

    test('fetchDashboardData returns DashboardDataUnavailable when endpoint is pending', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'Connection refused (endpoint not mounted)',
              ),
            );
          },
        ),
      );

      final apiClient = ApiClient(storage: storage, customDio: dio);
      final repository = DashboardRepository(
        storage: storage,
        apiClient: apiClient,
      );

      final result = await repository.fetchDashboardData();

      expect(result, isA<DashboardDataUnavailable>());
      final unavailable = result as DashboardDataUnavailable;
      expect(unavailable.contractNotice, contains('/api/v1/broker/dashboard'));
      expect(unavailable.contractNotice, contains('fabricated business data'));
    });

    test('fetchDashboardData returns DashboardDataUnauthorized on 401', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 401,
                  data: {'error': 'Unauthorized'},
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      final apiClient = ApiClient(storage: storage, customDio: dio);
      final repository = DashboardRepository(
        storage: storage,
        apiClient: apiClient,
      );

      final result = await repository.fetchDashboardData();
      expect(result, isA<DashboardDataUnauthorized>());
    });

    test('fetchDashboardData parses 200 JSON payload into DashboardDataSuccess', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'kpis': {
                    'activeDealsCount': 7,
                    'openRequirementsCount': 15,
                    'availableOffersCount': 9,
                    'partiallyAllocatedCount': 2,
                    'awaitingConfirmationCount': 3,
                    'dispatchDueCount': 1,
                    'deliveriesAwaitingConfirmationCount': 0,
                    'commissionThisMonth': '₹35,000',
                    'openDisputesCount': 0,
                  },
                  'recentActivity': [
                    {
                      'id': 'rec-1',
                      'title': 'Requirement Posted',
                      'description': 'Buyer Agarwal Mills requested 100 MT Chana',
                      'relativeTime': '5 min ago',
                      'category': 'requirements',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final apiClient = ApiClient(storage: storage, customDio: dio);
      final repository = DashboardRepository(
        storage: storage,
        apiClient: apiClient,
      );

      final result = await repository.fetchDashboardData();
      expect(result, isA<DashboardDataSuccess>());

      final success = result as DashboardDataSuccess;
      expect(success.metrics.activeDealsCount, equals(7));
      expect(success.metrics.openRequirementsCount, equals(15));
      expect(success.metrics.commissionThisMonth, equals('₹35,000'));
      expect(success.metrics.isAuthoritative, isTrue);
      expect(success.recentActivities.length, equals(1));
      expect(success.recentActivities[0].title, equals('Requirement Posted'));
    });
  });
}
