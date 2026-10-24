import 'package:supabase_flutter/supabase_flutter.dart';

/// Master-data references resolved from the configured live-test backend,
/// so live tests never depend on production commodity/grade/unit IDs.
class LiveMasterData {
  final String commodityId;
  final String commodityName;
  final String gradeId;
  final String gradeName;
  final String unitId;
  final String unitSymbol;

  const LiveMasterData({
    required this.commodityId,
    required this.commodityName,
    required this.gradeId,
    required this.gradeName,
    required this.unitId,
    required this.unitSymbol,
  });

  static Future<LiveMasterData> load(SupabaseClient client) async {
    final grades = await client
        .from('master_grades')
        .select('id, grade_name, commodity_id, master_commodities!inner(id, name, status)')
        .eq('master_commodities.status', true)
        .limit(1);
    final units = await client.from('master_units').select('id, symbol').limit(1);

    if (grades.isEmpty || units.isEmpty) {
      throw StateError('Live-test backend needs at least one active commodity with a grade, and one unit.');
    }

    final grade = grades.first;
    final commodity = grade['master_commodities'] as Map<String, dynamic>;
    final unit = units.first;

    return LiveMasterData(
      commodityId: commodity['id'] as String,
      commodityName: commodity['name'] as String,
      gradeId: grade['id'] as String,
      gradeName: grade['grade_name'] as String,
      unitId: unit['id'] as String,
      unitSymbol: (unit['symbol'] as String?) ?? '',
    );
  }
}
