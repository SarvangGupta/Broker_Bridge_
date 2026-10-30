import 'package:flutter/foundation.dart';
import '../../work/domain/offer_model.dart';
import '../../work/domain/requirement_model.dart';

/// Predefined date filter intervals.
enum DateFilterPreset {
  all('All'),
  today('Today'),
  yesterday('Yesterday'),
  last7Days('Last 7 Days'),
  last30Days('Last 30 Days'),
  thisMonth('This Month'),
  custom('Custom');

  final String label;
  const DateFilterPreset(this.label);
}

/// Supported sorting dimensions for home market items.
enum MarketSortOption {
  newestFirst('Newest First'),
  oldestFirst('Oldest First'),
  priceLowToHigh('Price: Low to High'),
  priceHighToLow('Price: High to Low'),
  quantityLowToHigh('Quantity: Low to High'),
  quantityHighToLow('Quantity: High to Low');

  final String label;
  const MarketSortOption(this.label);
}

/// Filter and sort criteria applied to Buyer Requirements and Seller Offers.
@immutable
class MarketFilterCriteria {
  final String? commodityId;
  final String? commodityName;
  final DateFilterPreset datePreset;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final double? minPrice;
  final double? maxPrice;
  final double? minQuantity;
  final double? maxQuantity;
  final MarketSortOption sortBy;

  const MarketFilterCriteria({
    this.commodityId,
    this.commodityName,
    this.datePreset = DateFilterPreset.all,
    this.customStartDate,
    this.customEndDate,
    this.minPrice,
    this.maxPrice,
    this.minQuantity,
    this.maxQuantity,
    this.sortBy = MarketSortOption.newestFirst,
  });

  const MarketFilterCriteria.empty()
      : commodityId = null,
        commodityName = null,
        datePreset = DateFilterPreset.all,
        customStartDate = null,
        customEndDate = null,
        minPrice = null,
        maxPrice = null,
        minQuantity = null,
        maxQuantity = null,
        sortBy = MarketSortOption.newestFirst;

  /// Returns how many filter criteria are currently active (excluding default sort).
  int get activeFilterCount {
    var count = 0;
    if (commodityId != null && commodityId!.isNotEmpty) count++;
    if (datePreset != DateFilterPreset.all) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (minQuantity != null || maxQuantity != null) count++;
    if (sortBy != MarketSortOption.newestFirst) count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;

  MarketFilterCriteria copyWith({
    String? Function()? commodityId,
    String? Function()? commodityName,
    DateFilterPreset? datePreset,
    DateTime? Function()? customStartDate,
    DateTime? Function()? customEndDate,
    double? Function()? minPrice,
    double? Function()? maxPrice,
    double? Function()? minQuantity,
    double? Function()? maxQuantity,
    MarketSortOption? sortBy,
  }) {
    return MarketFilterCriteria(
      commodityId: commodityId != null ? commodityId() : this.commodityId,
      commodityName: commodityName != null ? commodityName() : this.commodityName,
      datePreset: datePreset ?? this.datePreset,
      customStartDate: customStartDate != null ? customStartDate() : this.customStartDate,
      customEndDate: customEndDate != null ? customEndDate() : this.customEndDate,
      minPrice: minPrice != null ? minPrice() : this.minPrice,
      maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
      minQuantity: minQuantity != null ? minQuantity() : this.minQuantity,
      maxQuantity: maxQuantity != null ? maxQuantity() : this.maxQuantity,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// Evaluates whether a given creation timestamp satisfies the date filter.
  bool matchesDate(DateTime createdAt) {
    if (datePreset == DateFilterPreset.all) return true;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    switch (datePreset) {
      case DateFilterPreset.today:
        return createdAt.isAfter(todayStart) && createdAt.isBefore(todayEnd) ||
            createdAt.isAtSameMomentAs(todayStart) ||
            createdAt.isAtSameMomentAs(todayEnd);

      case DateFilterPreset.yesterday:
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        final yesterdayEnd = todayStart.subtract(const Duration(milliseconds: 1));
        return createdAt.isAfter(yesterdayStart) && createdAt.isBefore(yesterdayEnd) ||
            createdAt.isAtSameMomentAs(yesterdayStart) ||
            createdAt.isAtSameMomentAs(yesterdayEnd);

      case DateFilterPreset.last7Days:
        final start = todayStart.subtract(const Duration(days: 6));
        return createdAt.isAfter(start) || createdAt.isAtSameMomentAs(start);

      case DateFilterPreset.last30Days:
        final start = todayStart.subtract(const Duration(days: 29));
        return createdAt.isAfter(start) || createdAt.isAtSameMomentAs(start);

      case DateFilterPreset.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return createdAt.isAfter(monthStart) || createdAt.isAtSameMomentAs(monthStart);

      case DateFilterPreset.custom:
        if (customStartDate != null) {
          final start = DateTime(customStartDate!.year, customStartDate!.month, customStartDate!.day);
          if (createdAt.isBefore(start)) return false;
        }
        if (customEndDate != null) {
          final end = DateTime(customEndDate!.year, customEndDate!.month, customEndDate!.day, 23, 59, 59, 999);
          if (createdAt.isAfter(end)) return false;
        }
        return true;

      case DateFilterPreset.all:
        return true;
    }
  }

  /// Evaluates whether a RequirementItem matches all current filter conditions.
  bool matchesRequirement(RequirementItem req) {
    // 1. Raw Material (Commodity)
    if (commodityId != null && commodityId!.isNotEmpty && req.commodityId != commodityId) {
      return false;
    }

    // 2. Date
    if (!matchesDate(req.createdAt)) {
      return false;
    }

    // 3. Price (Target Price)
    if (minPrice != null && req.targetPrice < minPrice!) {
      return false;
    }
    if (maxPrice != null && req.targetPrice > maxPrice!) {
      return false;
    }

    // 4. Quantity (Requested Quantity)
    if (minQuantity != null && req.requestedQuantity < minQuantity!) {
      return false;
    }
    if (maxQuantity != null && req.requestedQuantity > maxQuantity!) {
      return false;
    }

    return true;
  }

  /// Evaluates whether an OfferItem matches all current filter conditions.
  bool matchesOffer(OfferItem offer) {
    // 1. Raw Material (Commodity)
    if (commodityId != null && commodityId!.isNotEmpty && offer.commodityId != commodityId) {
      return false;
    }

    // 2. Date
    if (!matchesDate(offer.createdAt)) {
      return false;
    }

    // 3. Price (Asking Price)
    if (minPrice != null && offer.askingPrice < minPrice!) {
      return false;
    }
    if (maxPrice != null && offer.askingPrice > maxPrice!) {
      return false;
    }

    // 4. Quantity (Available Quantity)
    final qty = offer.availableQuantity > 0 ? offer.availableQuantity : offer.offeredQuantity;
    if (minQuantity != null && qty < minQuantity!) {
      return false;
    }
    if (maxQuantity != null && qty > maxQuantity!) {
      return false;
    }

    return true;
  }

  /// Filters and sorts a list of RequirementItem according to active criteria.
  List<RequirementItem> applyToRequirements(List<RequirementItem> source) {
    final filtered = source.where(matchesRequirement).toList();

    switch (sortBy) {
      case MarketSortOption.newestFirst:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case MarketSortOption.oldestFirst:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case MarketSortOption.priceLowToHigh:
        filtered.sort((a, b) => a.targetPrice.compareTo(b.targetPrice));
      case MarketSortOption.priceHighToLow:
        filtered.sort((a, b) => b.targetPrice.compareTo(a.targetPrice));
      case MarketSortOption.quantityLowToHigh:
        filtered.sort((a, b) => a.requestedQuantity.compareTo(b.requestedQuantity));
      case MarketSortOption.quantityHighToLow:
        filtered.sort((a, b) => b.requestedQuantity.compareTo(a.requestedQuantity));
    }

    return filtered;
  }

  /// Filters and sorts a list of OfferItem according to active criteria.
  List<OfferItem> applyToOffers(List<OfferItem> source) {
    final filtered = source.where(matchesOffer).toList();

    switch (sortBy) {
      case MarketSortOption.newestFirst:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case MarketSortOption.oldestFirst:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case MarketSortOption.priceLowToHigh:
        filtered.sort((a, b) => a.askingPrice.compareTo(b.askingPrice));
      case MarketSortOption.priceHighToLow:
        filtered.sort((a, b) => b.askingPrice.compareTo(a.askingPrice));
      case MarketSortOption.quantityLowToHigh:
        filtered.sort((a, b) {
          final aQty = a.availableQuantity > 0 ? a.availableQuantity : a.offeredQuantity;
          final bQty = b.availableQuantity > 0 ? b.availableQuantity : b.offeredQuantity;
          return aQty.compareTo(bQty);
        });
      case MarketSortOption.quantityHighToLow:
        filtered.sort((a, b) {
          final aQty = a.availableQuantity > 0 ? a.availableQuantity : a.offeredQuantity;
          final bQty = b.availableQuantity > 0 ? b.availableQuantity : b.offeredQuantity;
          return bQty.compareTo(aQty);
        });
    }

    return filtered;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketFilterCriteria &&
          runtimeType == other.runtimeType &&
          commodityId == other.commodityId &&
          commodityName == other.commodityName &&
          datePreset == other.datePreset &&
          customStartDate == other.customStartDate &&
          customEndDate == other.customEndDate &&
          minPrice == other.minPrice &&
          maxPrice == other.maxPrice &&
          minQuantity == other.minQuantity &&
          maxQuantity == other.maxQuantity &&
          sortBy == other.sortBy;

  @override
  int get hashCode => Object.hash(
        commodityId,
        commodityName,
        datePreset,
        customStartDate,
        customEndDate,
        minPrice,
        maxPrice,
        minQuantity,
        maxQuantity,
        sortBy,
      );
}
