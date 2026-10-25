import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../requirements/data/requirements_repository.dart';
import '../../requirements/domain/master_requirement_data.dart';
import '../../requirements/presentation/commodity_picker_sheet.dart';
import '../domain/nutrition_guide_data.dart';
import 'raw_material_details_sheet.dart';
import '../../../l10n/app_localizations.dart';

/// Buyer guide to raw materials in the live Product Master: global search by
/// name or code, and browsing by approved parent category.
class NutritionGuideScreen extends StatefulWidget {
  final RequirementsRepository? repository;

  const NutritionGuideScreen({super.key, this.repository});

  @override
  State<NutritionGuideScreen> createState() => _NutritionGuideScreenState();
}

class _NutritionGuideScreenState extends State<NutritionGuideScreen> {
  late final RequirementsRepository _repo;
  final _searchController = TextEditingController();
  final _categorySearchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<MasterCommodity> _catalogue = [];
  List<MasterCategory>? _categories;
  String? _categoryError;
  MasterCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RequirementsRepository();
    _loadCatalogue();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categorySearchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogue() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _categoryError = null;
    });
    final categoriesFuture = _loadCategories();
    try {
      final catalogue = await _repo.getMasterCommodities();
      final categories = await categoriesFuture;
      if (!mounted) return;
      setState(() {
        _catalogue = catalogue;
        _categories = categories;
        if (categories == null ||
            !categories.any((c) => c.id == _selectedCategory?.id)) {
          _selectedCategory = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Nutrition guide catalogue load failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load the raw-material catalogue. Check your connection and retry.';
      });
    }
  }

  /// Categories fail separately: global search still works without them.
  Future<List<MasterCategory>?> _loadCategories() async {
    try {
      return await _repo.getMasterCategories();
    } catch (e) {
      debugPrint('Nutrition guide categories load failed: $e');
      if (mounted) {
        _categoryError = 'Could not load categories.';
      }
      return null;
    }
  }

  void _openCategory(MasterCategory category) {
    _categorySearchController.clear();
    setState(() => _selectedCategory = category);
  }

  void _closeCategory() => setState(() => _selectedCategory = null);

  void _openDetails(MasterCommodity m) {
    showRawMaterialDetailsSheet(
      context: context,
      material: m,
      repository: _repo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = _selectedCategory;
    return PopScope(
      canPop: category == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeCategory();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: category == null
              ? null
              : IconButton(
                  key: const Key('nutrition-category-back'),
                  icon: const Icon(LucideIcons.arrowLeft),
                  tooltip: 'All categories',
                  onPressed: _closeCategory,
                ),
          title: Text(category?.name ?? context.tr(Tr.titleNutrition)),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.rotateCw),
              tooltip: 'Refresh',
              onPressed: _loadCatalogue,
            ),
          ],
        ),
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingIndicator(message: 'Loading raw materials...');
    }
    if (_errorMessage != null) {
      return AppErrorState(message: _errorMessage!, onRetry: _loadCatalogue);
    }
    if (_catalogue.isEmpty) {
      return const AppEmptyState(
        title: 'No raw materials',
        description: 'No active raw materials are available in the catalogue.',
        icon: LucideIcons.package,
      );
    }
    final category = _selectedCategory;
    return category == null ? _buildHome() : _buildCategory(category);
  }

  Widget _buildHome() {
    final query = _searchController.text.trim();
    return CustomScrollView(
      slivers: [
        _pad(
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 12),
              AppTextField(
                key: const Key('nutrition-search'),
                controller: _searchController,
                hint: NutritionGuideData.searchHint,
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => setState(_searchController.clear),
                      ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
            ]),
          ),
        ),
        if (query.isNotEmpty)
          ..._buildResults(
            NutritionGuideData.search(_catalogue, query: query),
            query,
          )
        else ...[
          _pad(SliverToBoxAdapter(child: _buildDataNotice())),
          _pad(
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 14, bottom: 8),
                child: Text(
                  'Browse by category',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ),
          ),
          ..._buildCategoryCards(),
          _pad(SliverToBoxAdapter(child: _buildUnavailableGoals()), bottom: 24),
        ],
      ],
    );
  }

  Widget _buildCategory(MasterCategory category) {
    final query = _categorySearchController.text.trim();
    final inCategory = NutritionGuideData.search(
      _catalogue,
      categoryId: category.id,
    );
    return CustomScrollView(
      slivers: [
        _pad(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: AppTextField(
                key: const Key('nutrition-category-search'),
                controller: _categorySearchController,
                hint: 'Search in this category by name or code...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ),
        if (inCategory.isEmpty)
          _pad(
            const SliverToBoxAdapter(
              child: _Message('No active raw materials in this category yet.'),
            ),
          )
        else
          ..._buildResults(
            NutritionGuideData.search(inCategory, query: query),
            query,
          ),
      ],
    );
  }

  List<Widget> _buildResults(List<MasterCommodity> results, String query) {
    if (results.isEmpty) {
      return [
        _pad(
          SliverToBoxAdapter(
            child: _Message('No raw material matches "$query".'),
          ),
        ),
      ];
    }
    return [
      _pad(
        SliverList.separated(
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _buildMaterialCard(results[i]),
        ),
        bottom: 24,
      ),
    ];
  }

  List<Widget> _buildCategoryCards() {
    final categories = _categories;
    if (categories == null) {
      return [
        _pad(
          SliverToBoxAdapter(
            child: Column(
              children: [
                _Message(_categoryError ?? 'Could not load categories.'),
                TextButton.icon(
                  key: const Key('nutrition-categories-retry'),
                  onPressed: _loadCatalogue,
                  icon: const Icon(LucideIcons.rotateCw, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    if (categories.isEmpty) {
      return [
        _pad(
          const SliverToBoxAdapter(
            child: _Message('No active categories found.'),
          ),
        ),
      ];
    }
    final counts = NutritionGuideData.countsByCategory(_catalogue);
    return [
      _pad(
        SliverList.separated(
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = categories[i];
            final count = counts[c.id] ?? 0;
            return AppCard(
              key: Key('nutrition-category-${c.id}'),
              onTap: () => _openCategory(c),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          count == 0
                              ? 'No active products yet'
                              : '$count active product${count == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: count == 0
                                ? AppColors.textMutedLight
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: AppColors.textMutedLight,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildDataNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Categories follow the approved product master and are for browsing '
              'only. Nutrient values are not yet recorded, so confirm composition '
              'with a supplier lab report before formulating a ration.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(MasterCommodity m) {
    return AppCard(
      key: Key('nutrition-material-${m.id}'),
      onTap: () => _openDetails(m),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                CategoryLabel(categoryName: m.categoryName),
                if (m.code.isNotEmpty)
                  Text(
                    'Code: ${m.code}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMutedLight,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: AppColors.textMutedLight,
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableGoals() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Not available yet',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMutedLight,
            ),
          ),
          const SizedBox(height: 6),
          for (final u in NutritionGuideData.unavailableGoals)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${u.title}: ${u.reason}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pad(Widget sliver, {double bottom = 0}) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
      sliver: sliver,
    );
  }
}

class _Message extends StatelessWidget {
  final String text;

  const _Message(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}
