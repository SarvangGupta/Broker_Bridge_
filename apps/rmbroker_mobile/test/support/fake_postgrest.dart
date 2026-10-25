import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// One request seen by [FakePostgrest].
class FakeRequest {
  final String method;
  final String table;
  final Map<String, String> query;
  final Object? body;

  FakeRequest(this.method, this.table, this.query, this.body);

  /// Value of a filter parameter such as `id` → `eq.x`.
  String? filter(String column) => query[column];

  @override
  String toString() => '$method $table $query ${body ?? ''}';
}

/// Loopback, in-memory stand-in for PostgREST, enough for repository tests:
/// `eq.`, `neq.`, `is.null`, `not.is.null` filters, single-column `order`,
/// `limit`, GET/POST/PATCH with `return=representation`, the object Accept
/// header used by `single()`, and injectable failures.
///
/// Embedded resources are not resolved: store nested maps directly on rows.
/// Must be used from plain `test()` — `testWidgets` stubs HttpClient.
class FakePostgrest {
  final Map<String, List<Map<String, dynamic>>> tables;
  final List<FakeRequest> requests = [];

  /// Returns a (status, body) error for a request, or null to handle it normally.
  (int, Map<String, dynamic>)? Function(FakeRequest request)? failWith;

  /// Called before a PATCH is applied (e.g. to simulate a concurrent writer).
  void Function(FakeRequest request)? beforePatch;

  late final HttpServer _server;
  late final SupabaseClient client;
  int _ids = 0;

  FakePostgrest(this.tables);

  static Future<FakePostgrest> start(Map<String, List<Map<String, dynamic>>> tables) async {
    final fake = FakePostgrest(tables);
    fake._server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    fake._server.listen(fake._handle);
    fake.client = SupabaseClient('http://127.0.0.1:${fake._server.port}', 'test-anon-key');
    return fake;
  }

  Future<void> close() async {
    await client.dispose();
    await _server.close(force: true);
  }

  List<FakeRequest> writes() => requests.where((r) => r.method != 'GET').toList();

  List<FakeRequest> writesTo(String table) => writes().where((r) => r.table == table).toList();

  static bool _matches(Map<String, dynamic> row, String column, String expr) {
    final value = row[column];
    if (expr == 'is.null') return value == null;
    if (expr == 'not.is.null') return value != null;
    bool equals(String raw) {
      if (value == null) return raw == 'null';
      final a = num.tryParse(value.toString());
      final b = num.tryParse(raw);
      if (a != null && b != null) return a == b;
      return value.toString() == raw;
    }

    if (expr.startsWith('eq.')) return equals(expr.substring(3));
    if (expr.startsWith('neq.')) return !equals(expr.substring(4));
    return true;
  }

  static const _reserved = {'select', 'order', 'limit', 'offset', 'on_conflict', 'columns'};

  List<Map<String, dynamic>> _filtered(String table, Map<String, String> query) {
    var rows = (tables[table] ?? []).where((row) {
      for (final entry in query.entries) {
        if (_reserved.contains(entry.key) || entry.key.contains('.')) continue;
        if (!_matches(row, entry.key, entry.value)) return false;
      }
      return true;
    }).toList();
    final order = query['order'];
    if (order != null) {
      final parts = order.split(',').first.split('.');
      final column = parts.first;
      final desc = parts.length > 1 && parts[1] == 'desc';
      rows.sort((a, b) {
        final x = a[column]?.toString() ?? '';
        final y = b[column]?.toString() ?? '';
        final nx = num.tryParse(x);
        final ny = num.tryParse(y);
        final c = (nx != null && ny != null) ? nx.compareTo(ny) : x.compareTo(y);
        return desc ? -c : c;
      });
    }
    final limit = int.tryParse(query['limit'] ?? '');
    if (limit != null && rows.length > limit) rows = rows.sublist(0, limit);
    return rows;
  }

  Future<void> _handle(HttpRequest req) async {
    final table = req.uri.pathSegments.last;
    final raw = await utf8.decoder.bind(req).join();
    final body = raw.isEmpty ? null : jsonDecode(raw);
    final request = FakeRequest(req.method, table, req.uri.queryParameters, body);
    requests.add(request);

    final wantsObject = (req.headers.value('accept') ?? '').contains('vnd.pgrst.object');
    final wantsRows = (req.headers.value('prefer') ?? '').contains('return=representation');

    Future<void> send(int status, Object? payload) async {
      req.response.statusCode = status;
      req.response.headers.contentType = ContentType.json;
      if (payload != null) req.response.write(jsonEncode(payload));
      await req.response.close();
    }

    final failure = failWith?.call(request);
    if (failure != null) return send(failure.$1, failure.$2);

    List<Map<String, dynamic>> result;
    switch (req.method) {
      case 'GET':
        result = _filtered(table, request.query);
      case 'POST':
        final items = body is List ? body.cast<Map<String, dynamic>>() : [body as Map<String, dynamic>];
        result = [
          for (final item in items) {'id': 'gen-$table-${++_ids}', 'created_at': '2026-10-25T10:00:00.000', ...item},
        ];
        tables.putIfAbsent(table, () => []).addAll(result);
      case 'PATCH':
        beforePatch?.call(request);
        result = _filtered(table, request.query);
        for (final row in result) {
          row.addAll(body as Map<String, dynamic>);
        }
      default:
        result = [];
    }

    if (req.method != 'GET' && !wantsRows) return send(204, null);
    if (wantsObject) {
      if (result.length != 1) {
        return send(406, {'code': 'PGRST116', 'message': 'JSON object requested, multiple (or no) rows returned'});
      }
      return send(req.method == 'POST' ? 201 : 200, result.first);
    }
    return send(req.method == 'POST' ? 201 : 200, result);
  }
}
