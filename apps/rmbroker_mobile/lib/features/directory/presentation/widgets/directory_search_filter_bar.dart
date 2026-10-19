import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/directory_contact.dart';

/// Search input and segmented role/status filter bar for directory navigation.
class DirectorySearchFilterBar extends StatefulWidget {
  final String activeTab; // 'all' | 'buyer' | 'seller'
  final String searchQuery;
  final String statusFilter; // 'all' | 'active' | 'inactive'
  final DirectorySummaryStats stats;
  final ValueChanged<String> onTabChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onStatusFilterChanged;

  const DirectorySearchFilterBar({
    super.key,
    required this.activeTab,
    required this.searchQuery,
    required this.statusFilter,
    required this.stats,
    required this.onTabChanged,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onStatusFilterChanged,
  });

  @override
  State<DirectorySearchFilterBar> createState() => _DirectorySearchFilterBarState();
}

class _DirectorySearchFilterBarState extends State<DirectorySearchFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant DirectorySearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        _searchController.text != widget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Search Bar with Clear Icon
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: TextField(
              key: const Key('directory_search_field'),
              controller: _searchController,
              onChanged: widget.onSearchChanged,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name, company, phone, city...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textSecondary),
                suffixIcon: widget.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 16, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          widget.onClearSearch();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Segmented Role Tabs (All, Buyers, Sellers)
          Container(
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  key: const Key('tab_all'),
                  label: 'All',
                  count: widget.stats.totalContacts,
                  isSelected: widget.activeTab == 'all',
                  onTap: () => widget.onTabChanged('all'),
                ),
                _buildTabButton(
                  key: const Key('tab_buyers'),
                  label: 'Buyers',
                  count: widget.stats.buyersCount,
                  isSelected: widget.activeTab == 'buyer',
                  onTap: () => widget.onTabChanged('buyer'),
                ),
                _buildTabButton(
                  key: const Key('tab_sellers'),
                  label: 'Sellers',
                  count: widget.stats.sellersCount,
                  isSelected: widget.activeTab == 'seller',
                  onTap: () => widget.onTabChanged('seller'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 3. Status Filter Chips (All Status, Active, Archived)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Status:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  key: const Key('filter_status_all'),
                  label: 'All Status',
                  isSelected: widget.statusFilter == 'all',
                  onTap: () => widget.onStatusFilterChanged('all'),
                ),
                const SizedBox(width: 6),
                _buildStatusChip(
                  key: const Key('filter_status_active'),
                  label: 'Active Only',
                  isSelected: widget.statusFilter == 'active',
                  onTap: () => widget.onStatusFilterChanged('active'),
                ),
                const SizedBox(width: 6),
                _buildStatusChip(
                  key: const Key('filter_status_inactive'),
                  label: 'Archived',
                  isSelected: widget.statusFilter == 'inactive',
                  onTap: () => widget.onStatusFilterChanged('inactive'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required Key key,
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        key: key,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryNavy.withValues(alpha: 0.08)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.primaryNavy : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required Key key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryNavy : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
