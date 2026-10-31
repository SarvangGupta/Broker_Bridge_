import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/work_repository.dart';
import '../../domain/trade_master_data.dart';
import 'requirements_controller.dart';

final masterDataProvider = FutureProvider<TradeMasterData>((ref) async {
  final repo = ref.read(workRepositoryProvider);
  final res = await repo.getMasterData();
  if (res is WorkSuccess<TradeMasterData>) {
    return res.data;
  }
  return TradeMasterData.fallback();
});
