/// Search and parent-category browsing rules for the Buyer Nutrition Guide.
///
/// Categories and products come only from the live Product Master. Category
/// membership is the approved `master_commodities.category_id` link: it is
/// never inferred from a product name, and it supports browsing only, not
/// any claim about nutritional composition.
library;

import '../../requirements/domain/master_requirement_data.dart';

/// A requested nutrition view the guide cannot offer yet, with the missing data.
class UnavailableNutritionGoal {
  final String title;
  final String reason;

  const UnavailableNutritionGoal({required this.title, required this.reason});
}

class NutritionGuideData {
  const NutritionGuideData._();

  static const searchHint = 'Search raw material name or product code...';

  /// Requested views with no verified data behind them yet.
  static const List<UnavailableNutritionGoal> unavailableGoals = [
    UnavailableNutritionGoal(
      title: 'Calcium Source',
      reason: 'Calcium content is not recorded in the product master.',
    ),
    UnavailableNutritionGoal(
      title: 'Milk Production Support',
      reason: 'No verified data on milk yield or milk fat effects is recorded.',
    ),
    UnavailableNutritionGoal(
      title: 'Cost-Effective Options',
      reason: 'No verified product prices or nutrient values exist to compare cost per nutrient.',
    ),
  ];

  /// Active products matching [query] by name or code, optionally limited to
  /// the products linked to [categoryId].
  static List<MasterCommodity> search(
    List<MasterCommodity> catalogue, {
    String query = '',
    String? categoryId,
  }) {
    final q = query.trim().toLowerCase();
    return catalogue
        .where((c) => categoryId == null || c.categoryId == categoryId)
        .where(
          (c) =>
              q.isEmpty ||
              c.name.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Active product count per category id, from the loaded catalogue.
  static Map<String, int> countsByCategory(List<MasterCommodity> catalogue) {
    final counts = <String, int>{};
    for (final c in catalogue) {
      final id = c.categoryId;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }
}
