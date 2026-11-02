import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/network/api_client.dart';
import 'package:rmbroker_mobile/features/deals/data/deal_repository.dart';
import 'package:rmbroker_mobile/features/deals/domain/allocation_model.dart';

import '../../support/fake_postgrest.dart';
import '../directory/directory_repository_test.dart' show MockSecureStorageService;

// RM-CHAT-ALLOCATION-PRIVACY-E2E-02: the app uses broker_allocate_lot (proposed
// 0068) when it is deployed. Plain test(): loopback fake, no real database.

const broker = 'b0000000-0000-4000-8000-000000000001';
const reqId = 'a0000000-0000-4000-8000-000000000001';
const lotId = 'c0000000-0000-4000-8000-000000000001';

class _Repo extends DealRepository {
  _Repo(FakePostgrest fake)
      : super(
          apiClient: ApiClient(
            storage: MockSecureStorageService(),
            customDio: Dio()
              ..interceptors.add(InterceptorsWrapper(
                onRequest: (o, h) => h.reject(DioException(requestOptions: o, type: DioExceptionType.connectionError)),
              )),
          ),
          supabase: fake.client,
          storage: MockSecureStorageService(),
        );

  @override
  String? activeBrokerId() => broker;
}

CreateAllocationDto dto() => CreateAllocationDto(
      requirementId: reqId,
      availabilityId: lotId,
      proposedQuantity: 10,
      unitSymbol: 'MT',
      remainingRequirementQuantity: 50,
      availableOfferQuantity: 100,
      agreedPrice: 5900,
    );

void main() {
  late FakePostgrest fake;
  tearDown(() => fake.close());

  test('deployed function: one atomic call, no table writes from the app', () async {
    fake = await FakePostgrest.start({'requirements': [], 'availabilities': [], 'requirement_allocations': []});
    fake.failWith = (r) => r.isRpc && r.table == 'broker_allocate_lot'
        ? (200, {
            'id': 'alloc-1',
            'allocation_reference': 'ALC-1',
            'requirement_id': reqId,
            'availability_id': lotId,
            'broker_id': broker,
            'allocated_quantity': 10,
            'status': 'CONFIRMED',
          })
        : null;

    final result = await _Repo(fake).proposeAllocation(dto());

    expect(result, isA<DealSuccess<AllocationItem>>());
    final a = (result as DealSuccess<AllocationItem>).data;
    expect(a.requirementId, reqId);
    expect(a.availabilityId, lotId);
    final call = fake.requests.singleWhere((r) => r.isRpc);
    expect(call.body, containsPair('p_requirement_id', reqId));
    expect(call.body, containsPair('p_availability_id', lotId));
    expect(call.body, containsPair('p_quantity', 10.0));
    expect(fake.writes(), isEmpty, reason: 'the database function does every write');
  });

  test('the database refusal (e.g. duplicate allocation) is shown, with no fallback writes', () async {
    fake = await FakePostgrest.start({'requirements': [], 'availabilities': [], 'requirement_allocations': []});
    fake.failWith = (r) => r.isRpc
        ? (409, {'code': '23505', 'message': 'This seller lot is already allocated to this requirement'})
        : null;

    final result = await _Repo(fake).proposeAllocation(dto());

    expect(result, isA<DealError>());
    expect((result as DealError).message, contains('already allocated'));
    expect(fake.writes(), isEmpty);
  });

  test('not deployed (PGRST202): falls back to the existing path, which explains unassigned lots', () async {
    fake = await FakePostgrest.start({
      'requirements': [
        {
          'id': reqId, 'broker_id': broker, 'status': 'Open', 'quantity': 50, 'fulfilled_quantity': 0,
          'unit_id': 'u', 'commodity_id': 'maize',
          'target_date': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
          'master_units': {'id': 'u', 'name': 'Metric Tonne', 'symbol': 'MT'},
        },
      ],
      'availabilities': [
        {
          'id': lotId, 'broker_id': null, 'status': 'Open', 'commodity_id': 'maize', 'available_quantity': 100,
          'valid_until': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
          'master_units': {'symbol': 'MT'},
        },
      ],
      'requirement_allocations': [],
    });

    final result = await _Repo(fake).proposeAllocation(dto());

    expect(result, isA<DealError>());
    expect((result as DealError).message, contains('no broker yet'));
    expect(fake.writes(), isEmpty);
  });
}
