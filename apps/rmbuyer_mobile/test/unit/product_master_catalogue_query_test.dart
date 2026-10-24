import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmbuyer_mobile/features/requirements/data/requirements_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_requirements_repository.dart';
import '../support/network_guard.dart';

// No TestWidgetsFlutterBinding here: it would replace HttpClient with a stub that
// answers 400. The global fail-closed guard stays active and only allows loopback.
void main() {
  test('getMasterCommodities queries the shared Product Master for active products', () async {
    expect(HttpOverrides.current, isA<TestNetworkGuardOverrides>());

    // Local fake PostgREST endpoint on loopback.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <Uri>[];
    server.listen((req) async {
      requests.add(req.uri);
      // Serve what PostgREST returns for each table the repository reads.
      final Object body = req.uri.path.endsWith('/master_categories')
          ? [for (final e in productMasterCategories.entries) {'id': e.key, 'name': e.value}]
          : productMasterRows.where((r) => r['status'] == true).toList();
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await req.response.close();
    });
    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-anon-key');
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    final commodities = await RequirementsRepository(client: client).getMasterCommodities();

    expect(requests.map((u) => u.path), ['/rest/v1/master_commodities', '/rest/v1/master_categories']);
    final uri = requests.first;
    expect(uri.queryParameters['status'], 'eq.true');
    expect(uri.queryParameters['select'], 'id,name,code,status,category_id');
    expect(uri.queryParameters['order'], startsWith('name.asc'));

    final byName = {for (final c in commodities) c.name: c};
    expect(byName['Yellow Maize (Corn)']!.id, maizeId);
    expect(byName['Sharbati Wheat']!.id, wheatId);
    expect(byName['Soybean Seed']!.id, soybeanId);
    expect(byName['Soybean DOC']!.categoryName, 'Oil Cakes & Oil Meals');
    expect(byName.containsKey('maize'), isFalse);
    expect(byName.containsKey('Wheat'), isFalse);
  });

  test('a failed category read leaves products loadable with no guessed category', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final isCategories = req.uri.path.endsWith('/master_categories');
      req.response
        ..statusCode = isCategories ? 403 : 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(isCategories
            ? {'message': 'permission denied for table master_categories', 'code': '42501'}
            : productMasterRows.where((r) => r['status'] == true).toList()));
      await req.response.close();
    });
    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-anon-key');
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    final commodities = await RequirementsRepository(client: client).getMasterCommodities();

    expect(commodities, isNotEmpty);
    expect(commodities.every((c) => c.categoryName == null), isTrue);
  });

  test('getMasterCommodities surfaces a failed request instead of a fallback list', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      req.response
        ..statusCode = 500
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'message': 'upstream unavailable'}));
      await req.response.close();
    });
    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-anon-key');
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    await expectLater(
      RequirementsRepository(client: client).getMasterCommodities(),
      throwsA(isA<PostgrestException>()),
    );
  });
}
