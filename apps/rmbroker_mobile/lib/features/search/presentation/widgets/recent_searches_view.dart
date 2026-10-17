import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmbroker_mobile/app/theme/app_colors.dart';

/// Renders privately encrypted recent searches and suggested broker search terms.
class RecentSearchesView extends StatelessWidget {
  final List<String> recentSearches;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  const RecentSearchesView({
    super.key,
    required this.recentSearches,
    required this.onSelect,
    required this.onRemove,
    required this.onClearAll,
  });

  static const List<String> _suggestedTerms = [
    'Soyabean',
    'Mustard Seed',
    'Wheat Milling',
    'Chana Kota',
    'Jaipur Buyer',
    'Bikaner Seller',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: const [
                      Icon(LucideIcons.history, size: 16, color: AppColors.textSecondaryLight),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Recent Searches',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onClearAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Clear History',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentSearches.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.borderLight),
              itemBuilder: (context, index) {
                final term = recentSearches[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(LucideIcons.clock, size: 16, color: AppColors.textSecondaryLight),
                  title: Text(
                    term,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.x, size: 15, color: AppColors.textDisabled),
                    onPressed: () => onRemove(term),
                  ),
                  onTap: () => onSelect(term),
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          // Suggested Commodity Trading Terms
          Row(
            children: const [
              Icon(LucideIcons.sparkles, size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Explore Commodities & Mandis',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedTerms.map((term) {
              return ActionChip(
                label: Text(
                  term,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
                backgroundColor: AppColors.surfaceLight,
                side: const BorderSide(color: AppColors.borderLight),
                onPressed: () => onSelect(term),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
