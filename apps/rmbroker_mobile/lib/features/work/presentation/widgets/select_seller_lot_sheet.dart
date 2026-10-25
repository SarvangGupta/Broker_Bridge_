import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../deals/presentation/widgets/create_allocation_sheet.dart';
import '../../domain/match_model.dart';
import '../../domain/offer_model.dart';
import '../../domain/requirement_model.dart';
import '../controllers/offers_controller.dart';
import '../controllers/requirements_controller.dart';

/// Picks a seller lot to allocate to [requirement], on the requirement page.
///
/// Lots come from the broker's authorized offers source (RLS-scoped seller
/// companies; assigned or global lots), filtered by the existing match rules
/// (same commodity, active, quantity left) and verified sellers only.
/// Returns the chosen [OfferItem]; allocation itself is done by the caller.
class SelectSellerLotSheet extends ConsumerWidget {
  final RequirementItem requirement;

  const SelectSellerLotSheet({super.key, required this.requirement});

  static Future<OfferItem?> show(BuildContext context, RequirementItem requirement) {
    return showModalBottomSheet<OfferItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SelectSellerLotSheet(requirement: requirement),
    );
  }

  /// Allocate Seller: pick a lot, then record the allocation only (no deal)
  /// through the existing allocation sheet. The sheet refreshes requirements,
  /// offers and allocations after the backend confirms.
  static Future<void> allocate(BuildContext context, RequirementItem requirement) async {
    final offer = await show(context, requirement);
    if (offer == null || !context.mounted) return;
    await CreateAllocationSheet.show<void>(
      context: context,
      requirement: requirement,
      offer: offer,
      createDeal: false,
    );
  }

  /// Whether [requirement] can take an Allocate Seller action from [brokerId]:
  /// assigned to this broker and still open for allocation.
  static bool canAllocate(RequirementItem requirement, String? brokerId) =>
      brokerId != null && requirement.brokerId == brokerId && requirement.canBeMatched;

  /// Eligible lots: match rules, a verified seller, and a lot managed by this
  /// broker (the allocation step can only reserve stock on the broker's own
  /// lots; RLS blocks the update on any other desk's lot).
  static List<SupplyMatchItem> eligibleMatches(
    List<SupplyMatchItem> matches,
    String? brokerId,
  ) =>
      matches
          .where((m) => m.offer.isSellerVerified && brokerId != null && m.offer.brokerId == brokerId)
          .toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersState = ref.watch(offersProvider);
    final repo = ref.read(workRepositoryProvider);
    final matches = eligibleMatches(
      repo.computeMatches(requirement: requirement, availableOffers: offersState.offers),
      repo.activeBrokerId(),
    );
    final price = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final error = offersState.errorMessage ?? offersState.contractNotice;

    Widget body;
    if (offersState.isLoading && offersState.offers.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null && offersState.offers.isEmpty) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error, style: const TextStyle(fontSize: 12, color: AppColors.error)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('retry_load_sellers'),
            onPressed: () => ref.read(offersProvider.notifier).loadOffers(),
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: const Text('Retry'),
          ),
        ],
      );
    } else if (matches.isEmpty) {
      body = Text(
        'No verified seller has an active ${requirement.commodityName} lot managed by your desk.',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
      );
    } else {
      body = Column(
        children: [
          for (final m in matches)
            ListTile(
              key: ValueKey('seller_lot_${m.offer.id}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.shieldCheck, size: 18, color: AppColors.success),
              title: Text(
                m.offer.sellerCompanyName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${m.offer.lotNumber} · ${m.offer.gradeName} · '
                '${m.offer.availableQuantity.toStringAsFixed(0)} ${m.offer.unitSymbol} · '
                '${price.format(m.offer.askingPrice)}/${m.offer.unitSymbol} · ${m.offer.districtName}',
                style: const TextStyle(fontSize: 11.5),
              ),
              trailing: Text(
                m.classification.displayLabel,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              onTap: () => Navigator.pop(context, m.offer),
            ),
        ],
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Allocate Seller',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                '${requirement.ref} · ${requirement.commodityName} · '
                '${requirement.remainingQuantity.toStringAsFixed(0)} ${requirement.unitSymbol} remaining',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 12),
              body,
            ],
          ),
        ),
      ),
    );
  }
}
