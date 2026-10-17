import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmbroker_mobile/features/search/data/search_repository.dart';
import 'package:rmbroker_mobile/features/search/domain/search_result.dart';

/// Provider for quick dial contacts (speed-dial list).
final quickDialContactsProvider =
    FutureProvider.autoDispose<List<QuickDialContactItem>>((ref) async {
      final repository = ref.watch(searchRepositoryProvider);
      return repository.getQuickDialContacts();
    });
