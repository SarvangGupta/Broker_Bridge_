import 'commodity_model.dart';
import 'master_commodity_data.dart';

/// A product (and grade) the seller has listed before, for quick re-posting.
///
/// Carries only what is safe to reuse: product and grade identity. Quantity,
/// prices, availability dates, status and broker belong to the old lot and are
/// deliberately not copied into a new listing.
class PreviousCommodity {
  final String commodityId;
  final String? gradeId;
  final String commodityName;
  final String gradeName;
  final DateTime lastPostedAt;

  const PreviousCommodity({
    required this.commodityId,
    required this.gradeId,
    required this.commodityName,
    required this.gradeName,
    required this.lastPostedAt,
  });

  /// Distinct (product, grade) pairs from real listings, most recent first.
  /// Lots without a product id (legacy or sample rows) are skipped.
  static List<PreviousCommodity> fromListings(List<SellerCommodity> lots) {
    final sorted = [...lots]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final seen = <String>{};
    final out = <PreviousCommodity>[];
    for (final lot in sorted) {
      final id = lot.commodityId;
      if (id == null || id.isEmpty) continue;
      final key = '$id|${lot.gradeId ?? ''}';
      if (!seen.add(key)) continue;
      out.add(
        PreviousCommodity(
          commodityId: id,
          gradeId: lot.gradeId,
          commodityName: lot.commodityName,
          gradeName: lot.gradeName,
          lastPostedAt: lot.createdAt,
        ),
      );
    }
    return out;
  }
}

/// What the product picker returns: the product, plus the grade remembered
/// from a previous listing when the seller picked from their history.
class CommodityPick {
  final MasterCommodity commodity;
  final String? preferredGradeId;

  const CommodityPick(this.commodity, {this.preferredGradeId});
}
