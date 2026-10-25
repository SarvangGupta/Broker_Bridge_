import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/core/network/api_client.dart';
import 'package:rmbroker_mobile/core/security/secure_storage_service.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';

/// Row exactly as GET /api/v1/broker/requirements returns it
/// (src/server/utils/broker-requirements-query.ts), values from a live row.
final Map<String, dynamic> apiRow = {
  'id': 'f6e202aa-c5a1-49a5-bb74-97d3af532c5a',
  'company_id': '53b23dbe-df8e-4dbd-8ad8-322550ab8cdf',
  'commodity_id': '11111111-1111-1111-1111-111111111111',
  'grade_id': '22222222-2222-2222-2222-222222222222',
  'unit_id': '33333333-3333-3333-3333-333333333333',
  'broker_id': 'b354958e-779a-41f2-b7a3-5899eca32e32',
  'quantity': 53,
  'fulfilled_quantity': 0,
  'target_price': 5350,
  'delivery_terms_id': 'FOR Destination',
  'target_date': '2099-11-15T00:00:00.000Z',
  'status': 'Proposed to Buyer',
  'visibility': 'restricted',
  'created_at': '2026-10-19T22:08:46.921Z',
  'buyer_company_name': 'Gupta Feeds',
  'buyer_company_verified': false,
  'buyer_trust_score': 100,
  'commodity_name': 'Dal',
  'commodity_code': null,
  'category_name': 'Pulses',
  'grade_name': 'FAQ (Fair Average Quality)',
  'quality_parameters': null,
  'unit_name': 'Metric Tonne',
  'unit_symbol': 'MT',
};

void main() {
  late HttpServer server;
  late WorkRepository repo;
  late Object? Function() body;
  late int status;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'rmbroker_access_token': 'tok'});
    status = 200;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body()));
      await req.response.close();
    });
    final storage = SecureStorageService();
    repo = WorkRepository(
      storage: storage,
      apiClient: ApiClient(
        storage: storage,
        customDio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}/api/v1')),
      ),
    );
  });

  tearDown(() => server.close(force: true));

  test('parses the real API row into RequirementItem', () async {
    body = () => {
          'success': true,
          'data': {
            'requirements': [apiRow],
            'pageInfo': {'hasMore': false, 'nextCursor': null},
          },
        };
    final res = await repo.getRequirements();
    expect(res, isA<WorkSuccess<List<RequirementItem>>>());
    final r = (res as WorkSuccess<List<RequirementItem>>).data.single;
    expect(r.id, apiRow['id']);
    expect(r.buyerCompanyId, apiRow['company_id']);
    expect(r.buyerCompanyName, 'Gupta Feeds');
    expect(r.brokerId, apiRow['broker_id']);
    expect(r.commodityName, 'Dal');
    expect(r.unitSymbol, 'MT');
    expect(r.requestedQuantity, 53);
    expect(r.targetPrice, 5350);
    expect(r.targetDate.toUtc(), DateTime.utc(2099, 11, 15));
    expect(r.rawStatus, 'Proposed to Buyer');
    expect(r.createdAt.toUtc(), DateTime.utc(2026, 10, 19, 22, 8, 46, 921));
  });

  test('empty API list is an empty success, not a notice', () async {
    body = () => {
          'success': true,
          'data': {'requirements': [], 'pageInfo': {'hasMore': false, 'nextCursor': null}},
        };
    final res = await repo.getRequirements();
    expect(res, isA<WorkSuccess<List<RequirementItem>>>());
    expect((res as WorkSuccess<List<RequirementItem>>).data, isEmpty);
  });

  test('API 401 maps to WorkUnauthorized', () async {
    status = 401;
    body = () => {'success': false, 'error': 'Unauthorized: Valid broker session required'};
    expect(await repo.getRequirements(), isA<WorkUnauthorized>());
  });
}
