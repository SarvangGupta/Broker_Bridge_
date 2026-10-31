import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rmbroker_mobile/core/network/api_client.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:rmbroker_mobile/features/work/domain/offer_model.dart';
import 'package:rmbroker_mobile/features/work/domain/requirement_model.dart';

/// REST responds the way an undeployed route does: a non-JSON error body.
class _HtmlErrorApi implements ApiClient {
  final Object? body;
  _HtmlErrorApi(this.body);

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final request = RequestOptions(path: path);
    throw DioException(
      requestOptions: request,
      response: Response<dynamic>(requestOptions: request, statusCode: 404, data: body),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// No direct database path, so a handled REST failure ends in the connect error.
class _NoDbRepo extends WorkRepository {
  _NoDbRepo(Object? body) : super(apiClient: _HtmlErrorApi(body));

  @override
  Future<String?> validateProductGrade(String commodityId, String gradeId) async => null;
}

final _offer = CreateOfferDto(
  companyId: 's',
  commodityId: 'c',
  gradeId: 'g',
  quantity: 1,
  unitId: 'u',
  askingPrice: 1,
  stateId: 'st',
  districtId: 'd',
  availableFrom: DateTime(2026, 1, 1),
  validUntil: DateTime(2026, 2, 1),
);

final _requirement = CreateRequirementDto(
  companyId: 'b',
  commodityId: 'c',
  gradeId: 'g',
  quantity: 1,
  unitId: 'u',
  targetPrice: 1,
  deliveryTerms: 'FOR site',
  targetDate: DateTime.now().add(const Duration(days: 7)),
);

void main() {
  group('saved requirement contract', () {
    test('insert row keeps every chosen value and the location reference', () {
      final row = WorkRepository.requirementInsertRow(
        CreateRequirementDto(
          companyId: 'b', commodityId: 'c', gradeId: 'g', quantity: 12.5, unitId: 'u', targetPrice: 4800,
          deliveryTerms: 'Yard, Road, Kota, Rajasthan', targetDate: DateTime(2026, 12, 1), notes: 'Bagged',
          locationId: 'wh-1', locationSnapshot: 'Yard, Road, Kota, Rajasthan',
        ),
        'broker-1',
      );
      expect(row['company_id'], 'b');
      expect(row['commodity_id'], 'c');
      expect(row['grade_id'], 'g');
      expect(row['quantity'], 12.5);
      expect(row['unit_id'], 'u');
      expect(row['target_price'], 4800);
      expect(row['broker_id'], 'broker-1');
      expect(row['notes'], 'Bagged');
      expect(row['delivery_location_id'], 'wh-1');
      expect(row['delivery_location_snapshot'], 'Yard, Road, Kota, Rajasthan');
    });

    test('database errors become readable text without raw details', () {
      const missing = PostgrestException(
        message: "Could not find the 'delivery_location_id' column of 'requirements' in the schema cache",
        code: 'PGRST204',
      );
      final text = WorkRepository.saveErrorMessage(missing, 'requirement');
      expect(text, contains('Nothing was saved'));
      expect(text, isNot(contains('delivery_location_id')));
      expect(text, isNot(contains('PGRST')));
      expect(
        WorkRepository.saveErrorMessage(const PostgrestException(message: 'rls', code: '42501'), 'offer'),
        contains('permission'),
      );
      expect(WorkRepository.saveErrorMessage(Exception('socket'), 'offer'), contains('connection'));
    });
  });

  for (final (label, body) in [('HTML', '<html>404</html>'), ('empty', '')]) {
    test('offer save survives a $label REST error body and falls through', () async {
      final res = await _NoDbRepo(body).createOffer(_offer);
      expect((res as WorkError).message, contains('Unable to connect to offers service'));
    });

    test('requirement save survives a $label REST error body and falls through', () async {
      final res = await _NoDbRepo(body).createRequirement(_requirement);
      expect((res as WorkError).message, contains('Unable to connect to requirements service'));
    });
  }

  test('a JSON REST error is still reported as sent by the server', () async {
    final res = await _NoDbRepo({'error': 'Seller is suspended'}).createOffer(_offer);
    expect((res as WorkError).message, 'Seller is suspended');
  });
}
