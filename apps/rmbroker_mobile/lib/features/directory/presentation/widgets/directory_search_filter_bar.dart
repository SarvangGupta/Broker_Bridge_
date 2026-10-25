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
                hintText: 'Search by name, company or phone number...',
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

          // 2. Role tabs (All, Buyers, Sellers) with counts
          SizedBox(
            height: 42,
            child: Row(
              children: [
                _buildTabButton(
                  key: const Key('tab_all'),
                  label: 'All',
                  count: widget.stats.totalContacts,
                  isSelected: widget.activeTab == 'all',
                  onTap: () => widget.onTabChanged('all'),
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  key: const Key('tab_buyers'),
                  label: 'Buyers',
                  count: widget.stats.buyersCount,
                  isSelected: widget.activeTab == 'buyer',
                  onTap: () => widget.onTabChanged('buyer'),
                ),
                const SizedBox(width: 8),
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
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFDCFCE7) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF86EFAC) : AppColors.borderLight,
            ),
          ),
          child: Text(
            '$label ($count)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF14532D) : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
