import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/search_repository.dart';
import '../domain/search_model.dart';
import 'widgets/broker_result_card.dart';
import '../../../l10n/app_localizations.dart';

/// Interactive search screen for commodities and authorized brokers.
/// Includes category filter chips, debouncing, broker contact cards, and requirement posting CTA.
class BuyerSearchScreen extends StatefulWidget {
  final String? initialQuery;
  final SearchRepository? searchRepository;
  final ContactLauncherService? contactLauncher;

  const BuyerSearchScreen({
    super.key,
    this.initialQuery,
    this.searchRepository,
    this.contactLauncher,
  });

  @override
  State<BuyerSearchScreen> createState() => _BuyerSearchScreenState();
}

class _BuyerSearchScreenState extends State<BuyerSearchScreen> {
  late final TextEditingController _controller;
  late final SearchRepository _searchRepo;
  late final ContactLauncherService _contactLauncher;
  SearchCategory _selectedCategory = SearchCategory.all;

  Timer? _debounceTimer;
  bool _isLoading = false;
  String? _errorMessage;
  List<SearchItem> _results = [];
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    _searchRepo = widget.searchRepository ?? SearchRepository();
    _contactLauncher = widget.contactLauncher ?? ContactLauncherService();

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _executeSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim();

    if (clean.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(clean);
    });
  }

  Future<void> _executeSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final items = await _searchRepo.search(
        query: clean,
        category: _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _results = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to complete search. Please verify your connection.';
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _controller.clear();
    setState(() {
      _results = [];
      _hasSearched = false;
      _errorMessage = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(Tr.titleSearch)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Bar with Filter Chips
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              color: AppColors.surfaceLight,
              child: Column(
                children: [
                  AppTextField(
                    controller: _controller,
                    hint: 'Search commodity or broker',
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 18),
                            onPressed: _clearSearch,
                          )
                        : null,
                    onChanged: _onQueryChanged,
                    onSubmitted: _executeSearch,
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip('All Results', SearchCategory.all),
                        const SizedBox(width: 8),
                        _buildCategoryChip('Commodities', SearchCategory.commodities),
                        const SizedBox(width: 8),
                        _buildCategoryChip('Authorized Brokers', SearchCategory.brokers),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Search Content Area
            Expanded(
              child: _buildSearchBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, SearchCategory cat) {
    final isSelected = _selectedCategory == cat;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedCategory = cat;
          });
          if (_controller.text.trim().isNotEmpty) {
            _executeSearch(_controller.text);
          }
        }
      },
      selectedColor: AppColors.primaryContainer,
      backgroundColor: AppColors.surfaceLight,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppColors.primaryDark : AppColors.textSecondaryLight,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.borderLight,
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildSearchBody() {
    if (_isLoading) {
      return const AppLoadingIndicator(message: 'Searching commodities and brokers...');
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        onRetry: () => _executeSearch(_controller.text),
      );
    }

    if (!_hasSearched || _controller.text.trim().isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.search,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Instant Commodity & Broker Discovery',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Type a commodity name (e.g., Soybean, Chana, Wheat) or search licensed mandi broker desks.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Quick suggestion chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildSuggestionChip('Soybean'),
                  _buildSuggestionChip('Desi Chana'),
                  _buildSuggestionChip('Wheat'),
                  _buildSuggestionChip('Mustard'),
                  _buildSuggestionChip('Jaipur Broker'),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return AppEmptyState(
        title: 'No matching broker found.',
        description:
            'Cannot find "${_controller.text}"? Post your requirement directly to broadcast to licensed mandi brokers.',
        icon: LucideIcons.searchX,
        actionLabel: 'Post Your Requirement',
        onAction: () => context.push('/requirements/new'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _results[index];

        if (item.isBroker && item.broker != null) {
          return BrokerResultCard(
            broker: item.broker!,
            contactLauncher: _contactLauncher,
          );
        }

        // Commodity Item
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onTap: () {
            if (item.isCommodity) {
              context.push(
                '/requirements/new?commodity=${Uri.encodeComponent(item.title)}',
              );
            }
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.isCommodity
                      ? AppColors.primaryContainer
                      : AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.isCommodity ? LucideIcons.package : LucideIcons.briefcase,
                  size: 20,
                  color: item.isCommodity
                      ? AppColors.primary
                      : AppColors.secondaryDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.isCommodity)
                const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMutedLight),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestionChip(String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        _controller.text = label;
        _executeSearch(label);
      },
      backgroundColor: AppColors.surfaceLight,
      side: const BorderSide(color: AppColors.borderLight),
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimaryLight),
    );
  }
}
