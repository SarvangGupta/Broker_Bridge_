import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/search_repository.dart';
import '../domain/broker_model.dart';
import 'widgets/broker_result_card.dart';

/// Short market label for a broker's location, e.g. "Jaipur Mandi, Rajasthan"
/// becomes "Jaipur". Null when the broker has no real location.
String? brokerMarketLabel(BrokerModel broker) {
  final loc = brokerDisplayLocation(broker);
  if (loc == null) return null;
  final first = loc.split(',').first.trim();
  final label = first
      .replaceAll(RegExp(r'\s+mandi$', caseSensitive: false), '')
      .trim();
  return label.isEmpty ? null : label;
}

/// Authorized mandi broker listing opened from the central Brokers tab.
/// Loads the directory once, then filters locally by market and by a search
/// over name, mandi, firm and commodities.
class BrokersScreen extends StatefulWidget {
  final SearchRepository? searchRepository;
  final ContactLauncherService? contactLauncher;

  const BrokersScreen({super.key, this.searchRepository, this.contactLauncher});

  @override
  State<BrokersScreen> createState() => _BrokersScreenState();
}

class _BrokersScreenState extends State<BrokersScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final SearchRepository _searchRepo;
  late final ContactLauncherService _contactLauncher;

  List<BrokerModel> _brokers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedMarket;
  bool _verifiedOnly = false;

  @override
  void initState() {
    super.initState();
    _searchRepo = widget.searchRepository ?? SearchRepository();
    _contactLauncher = widget.contactLauncher ?? ContactLauncherService();
    _loadBrokers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBrokers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final brokers = await _searchRepo.searchBrokers(query: '');
      if (!mounted) return;
      setState(() {
        _brokers = brokers;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unable to load broker desks. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  /// Distinct markets present in the loaded data, most common first.
  List<String> get _markets {
    final counts = <String, int>{};
    for (final b in _brokers) {
      final m = brokerMarketLabel(b);
      if (m != null) counts[m] = (counts[m] ?? 0) + 1;
    }
    final list = counts.keys.toList()
      ..sort((a, b) {
        final c = counts[b]!.compareTo(counts[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    return list;
  }

  List<BrokerModel> get _visibleBrokers {
    final term = _searchController.text.trim().toLowerCase();
    return _brokers.where((b) {
      if (_verifiedOnly && !b.isVerified) return false;
      if (_selectedMarket != null && brokerMarketLabel(b) != _selectedMarket) {
        return false;
      }
      if (term.isEmpty) return true;
      final commodities = b.hasCommodityData
          ? b.commoditiesHandled
          : const <String>[];
      return b.name.toLowerCase().contains(term) ||
          (brokerDisplayLocation(b)?.toLowerCase().contains(term) ?? false) ||
          (brokerFirmName(b)?.toLowerCase().contains(term) ?? false) ||
          commodities.any((c) => c.toLowerCase().contains(term));
    }).toList();
  }

  Future<void> _showMoreMarkets(List<String> extra, {String? title}) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (extra.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text(
                  'No broker locations are available to filter by yet.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ),
            if (title != null && _selectedMarket != null)
              ListTile(
                leading: const Icon(LucideIcons.filterX, size: 18),
                title: const Text('All locations'),
                onTap: () => Navigator.of(ctx).pop(''),
              ),
            for (final m in extra)
              ListTile(
                leading: const Icon(LucideIcons.mapPin, size: 18),
                title: Text(m),
                trailing: m == _selectedMarket
                    ? const Icon(
                        LucideIcons.check,
                        size: 18,
                        color: AppColors.primary,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(m),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedMarket = picked.isEmpty ? null : picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBrokers,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildHeader()),
              ),
              ..._buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final allSelected = !_verifiedOnly && _selectedMarket == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Mandi Brokers',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryLight,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
            Material(
              color: AppColors.successBackground,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: const Key('brokers-refresh'),
                borderRadius: BorderRadius.circular(12),
                onTap: _isLoading ? null : _loadBrokers,
                child: const Tooltip(
                  message: 'Refresh',
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      LucideIcons.rotateCw,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Connect with trusted brokers for your procurement needs.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _searchController,
          hint: 'Search by broker name, mandi or commodity...',
          prefixIcon: const Icon(LucideIcons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => setState(_searchController.clear),
                )
              : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        // Wraps instead of scrolling so every chip stays reachable on
        // narrow phones.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip(
              key: const Key('filter-all'),
              label: _isLoading
                  ? 'All Brokers'
                  : 'All Brokers (${_brokers.length})',
              selected: allSelected,
              onTap: () => setState(() {
                _verifiedOnly = false;
                _selectedMarket = null;
              }),
            ),
            _filterChip(
              key: const Key('filter-verified'),
              label: 'Verified',
              icon: LucideIcons.shieldCheck,
              selected: _verifiedOnly,
              onTap: () => setState(() => _verifiedOnly = !_verifiedOnly),
            ),
            _filterChip(
              key: const Key('broker-filter-button'),
              label: _selectedMarket ?? 'Filters',
              icon: LucideIcons.slidersHorizontal,
              selected: _selectedMarket != null,
              onTap: () =>
                  _showMoreMarkets(_markets, title: 'Filter by location'),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _filterChip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final fg = selected ? Colors.white : AppColors.primary;
    return Material(
      color: selected ? AppColors.primary : AppColors.successBackground,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    if (_isLoading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppLoadingIndicator(
            message: 'Loading verified broker desks...',
          ),
        ),
      ];
    }
    if (_errorMessage != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppErrorState(message: _errorMessage!, onRetry: _loadBrokers),
        ),
      ];
    }

    final visible = _visibleBrokers;
    if (visible.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              _brokers.isEmpty
                  ? 'No authorized brokers currently listed.'
                  : 'No brokers match your search or filters.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverList.separated(
          itemCount: visible.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => BrokerResultCard(
            broker: visible[index],
            contactLauncher: _contactLauncher,
          ),
        ),
      ),
    ];
  }
}
