import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/core/widgets/app_empty_state.dart';
import 'package:rmbroker_mobile/core/widgets/app_error_state.dart';
import 'package:rmbroker_mobile/features/search/domain/search_result.dart';
import 'package:rmbroker_mobile/features/search/domain/search_state.dart';
import 'package:rmbroker_mobile/features/search/presentation/controllers/search_controller.dart';
import 'package:rmbroker_mobile/features/search/presentation/widgets/quick_communication_sheet.dart';
import 'package:rmbroker_mobile/features/search/presentation/widgets/recent_searches_view.dart';
import 'package:rmbroker_mobile/features/search/presentation/widgets/search_filter_tabs.dart';
import 'package:rmbroker_mobile/features/search/presentation/widgets/search_input_bar.dart';
import 'package:rmbroker_mobile/features/search/presentation/widgets/search_results_view.dart';

/// Full-screen unified global search workstation for RMBroker.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final SearchEntityType? initialFilter;

  const GlobalSearchScreen({
    super.key,
    this.initialQuery,
    this.initialFilter,
  });

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialQuery ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialFilter != null) {
        ref.read(searchControllerProvider.notifier).setFilter(widget.initialFilter!);
      }
      if (widget.initialQuery != null && widget.initialQuery!.trim().length >= 2) {
        ref.read(searchControllerProvider.notifier).onQueryChanged(widget.initialQuery!);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 22),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SearchInputBar(
            controller: _textController,
            isDebouncing: state.isDebouncing,
            isLoading: state.isLoading,
            onChanged: (val) => controller.onQueryChanged(val),
            onSubmitted: () => controller.executeSearch(addToRecent: true),
            onClear: () {
              controller.clearQuery();
            },
            onVoiceQuerySelected: (recognized) {
              _textController.text = recognized;
              controller.selectRecentSearch(recognized);
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.phoneCall, size: 20),
            tooltip: 'Speed Dial',
            color: AppColors.primary,
            onPressed: () => QuickCommunicationSheet.show(context),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: AppColors.backgroundLight,
            child: SearchFilterTabs(
              selectedFilter: state.activeFilter,
              counts: state.counts,
              onFilterSelected: (filter) => controller.setFilter(filter),
            ),
          ),
        ),
      ),
      body: _buildBody(context, state, controller),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SearchState state,
    BrokerSearchController controller,
  ) {
    // 1. Loading State
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'Searching RMBroker desk records...',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // 2. Query empty -> Recent Searches & Suggestions
    if (state.isEmpty) {
      return RecentSearchesView(
        recentSearches: state.recentSearches,
        onSelect: (term) {
          _textController.text = term;
          controller.selectRecentSearch(term);
        },
        onRemove: (term) => controller.removeRecentSearch(term),
        onClearAll: () => controller.clearRecentSearches(),
      );
    }

    // 3. Query too short
    if (state.isQueryTooShort) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(LucideIcons.search, size: 40, color: AppColors.textDisabled),
              SizedBox(height: 12),
              Text(
                'Keep typing...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Enter at least 2 characters to search across buyers, sellers, commodities, mandates, and deals.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Contract Pending Notice (Zero-Fabrication principle)
    if (state.isContractPending) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            color: AppColors.surfaceLight,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.goldMuted.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.fileSearch,
                      size: 28,
                      color: AppColors.goldDark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Global Search Service Contract Pending',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.contractNotice ??
                        'The unified search endpoint (/api/v1/broker/search) is pending exposure on the Next.js backend. Dedicated counterparty and mandate desks remain operational.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(LucideIcons.refreshCw, size: 14),
                        label: const Text('Retry Search'),
                        onPressed: () => controller.executeSearch(addToRecent: false),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(LucideIcons.users, size: 14),
                        label: const Text('Go to Directory'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => context.go('/directory'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 5. Network / Server Error
    if (state.errorMessage != null) {
      return AppErrorState(
        message: state.errorMessage!,
        onRetry: () => controller.executeSearch(addToRecent: false),
      );
    }

    // 6. No Results Found
    if (state.hasNoResults) {
      return AppEmptyState(
        title: 'No results found',
        description: 'No matching records found for "${state.query}". Check spelling or try searching for commodity name, phone number, or firm name.',
        icon: LucideIcons.searchX,
        actionLabel: 'Clear Search',
        onAction: () {
          _textController.clear();
          controller.clearQuery();
        },
      );
    }

    // 7. Results Found
    return SearchResultsView(
      results: state.results,
      activeFilter: state.activeFilter,
      query: state.query,
    );
  }
}
