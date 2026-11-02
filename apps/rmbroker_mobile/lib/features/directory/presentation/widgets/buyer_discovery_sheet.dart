import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/directory_repository.dart';
import '../../domain/directory_contact.dart';
import '../controllers/directory_controller.dart';

/// Finds existing buyers and adds them to the broker's list by their existing
/// identity. Uses the directory's current category filter.
class BuyerDiscoverySheet extends ConsumerStatefulWidget {
  const BuyerDiscoverySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const BuyerDiscoverySheet(),
    );
  }

  @override
  ConsumerState<BuyerDiscoverySheet> createState() => _BuyerDiscoverySheetState();
}

class _BuyerDiscoverySheetState extends ConsumerState<BuyerDiscoverySheet> {
  static const _minSearch = 3;

  Timer? _debounce;
  String _query = '';
  int _generation = 0;
  bool _loading = false;
  String? _error;
  bool _hasSearched = false;
  List<DiscoverableBuyer> _results = const [];
  final Set<String> _adding = {};

  /// Buyers added while this sheet is open, shown as already added at once.
  final Set<String> _added = {};

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _query = value.trim();
    // Any edit makes a request still in flight stale.
    _generation++;
    _debounce?.cancel();
    _debounce = Timer(DirectoryController.searchDebounce, _search);
  }

  Future<void> _search() async {
    final generation = ++_generation;
    if (_query.length < _minSearch) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
        _hasSearched = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _results = const [];
      _hasSearched = false;
    });
    final result = await ref.read(directoryRepositoryProvider).discoverBuyers(
          search: _query,
          categoryId: ref.read(directoryControllerProvider).categoryFilter,
        );
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      switch (result) {
        case DirectorySuccess<List<DiscoverableBuyer>>(:final data):
          _results = data;
          _hasSearched = true;
        case DirectoryError<List<DiscoverableBuyer>>(:final message):
          _error = message;
        case DirectoryUnauthorized<List<DiscoverableBuyer>>(:final message):
          _error = message;
        case DirectoryUnavailable<List<DiscoverableBuyer>>(:final contractNotice):
          _error = contractNotice;
      }
    });
  }

  Future<void> _add(DiscoverableBuyer buyer) async {
    if (!_adding.add(buyer.userId)) return;
    setState(() {});
    final result = await ref.read(directoryRepositoryProvider).addExistingBuyer(buyer.userId);
    if (!mounted) return;
    _adding.remove(buyer.userId);
    if (result is DirectorySuccess<String>) {
      _added.add(buyer.userId);
      setState(() {});
      await ref.read(directoryControllerProvider.notifier).loadContacts(isRefresh: true);
      return;
    }
    setState(() {});
    final message = switch (result) {
      DirectoryError<String>(:final message) => message,
      DirectoryUnauthorized<String>(:final message) => message,
      DirectoryUnavailable<String>(:final contractNotice) => contractNotice,
      DirectorySuccess<String>() => '',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Find Existing Buyer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('buyer_discovery_search'),
            autofocus: true,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              hintText: 'Name, company, mobile, email or GSTIN',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            TextButton(
              key: const Key('buyer_discovery_retry'),
              onPressed: _search,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final message = _query.length < _minSearch
        ? 'Type at least $_minSearch characters to search.'
        : (_hasSearched && _results.isEmpty ? 'No buyers found.' : null);
    if (message != null) {
      return Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.borderLight),
      itemBuilder: (_, i) => _buildRow(_results[i]),
    );
  }

  Widget _buildRow(DiscoverableBuyer buyer) {
    final isAdded = buyer.isAlreadyAdded || _added.contains(buyer.userId);
    final isAdding = _adding.contains(buyer.userId);
    return ListTile(
      key: Key('buyer_result_${buyer.userId}'),
      contentPadding: EdgeInsets.zero,
      title: Text(buyer.companyName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      subtitle: Text(
        [
          buyer.name,
          ?buyer.location,
          buyer.categoriesLabel,
          ?buyer.maskedGstin,
          if (buyer.isVerificationPending) 'Verification Pending',
        ].join('\n'),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: isAdded
          ? const Text('Already Added', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
          : TextButton(
              key: Key('buyer_add_${buyer.userId}'),
              onPressed: isAdding ? null : () => _add(buyer),
              child: const Text('Add to My List'),
            ),
    );
  }
}
