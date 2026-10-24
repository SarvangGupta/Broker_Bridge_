import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmbroker_mobile/features/work/data/work_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Kept free of testWidgets: TestWidgetsFlutterBinding stubs HttpClient (every request → 400),
// which would hide the loopback fake PostgREST below.
const maize = '20000000-0000-0000-0000-000000000001';
const maizeGradeA = '21000000-0000-0000-0000-000000000001';
const wheatBranFaq = '5dcb586c-632a-50c0-b097-a33efae04a20';

Future<(HttpServer, SupabaseClient, List<Uri>)> fakeServer(List<Map<String, dynamic>> body) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final requests = <Uri>[];
  server.listen((req) async {
    requests.add(req.uri);
    req.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await req.response.close();
  });
  final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-anon-key');
  return (server, client, requests);
}

void main() {
  group('WorkRepository.validateProductGrade (KI-43 database guard)', () {
    test('accepts a grade that belongs to the active product, filtering by both ids', () async {
      final (server, client, requests) = await fakeServer([
        {'id': maizeGradeA, 'commodity_id': maize, 'master_commodities': {'status': true}},
      ]);
      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
      });

      final err = await WorkRepository(supabase: client).validateProductGrade(maize, maizeGradeA);

      expect(err, isNull);
      final q = requests.single.queryParameters;
      expect(requests.single.path, '/rest/v1/master_grades');
      expect(q['id'], 'eq.$maizeGradeA');
      expect(q['commodity_id'], 'eq.$maize');
      expect(q['master_commodities.status'], 'eq.true');
    });

    test('rejects an incompatible product-grade pair', () async {
      final (server, client, _) = await fakeServer([]);
      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
      });

      final err = await WorkRepository(supabase: client).validateProductGrade(maize, wheatBranFaq);

      expect(err, 'The selected grade does not belong to the selected product.');
    });
  });
}
