import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../deals/domain/allocation_model.dart';
import '../../../deals/presentation/controllers/allocations_controller.dart';
import '../../../deals/presentation/widgets/create_allocation_sheet.dart';
import '../../domain/match_model.dart';
import '../../domain/offer_model.dart';
import '../../domain/requirement_model.dart';
import '../controllers/offers_controller.dart';
import '../controllers/requirements_controller.dart';

/// A matching seller lot and why it cannot be allocated (null: selectable).
class SellerCandidate {
  final SupplyMatchItem match;
  final String? blockedReason;

  const SellerCandidate(this.match, this.blockedReason);

  bool get canSelect => blockedReason == null;
}

/// Picks a seller lot to allocate to [requirement], on the requirement page.
///
/// Lots come from the broker's authorized offers source (the broker's own or
/// global lots under RLS), filtered by the existing match rules (same
/// canonical commodity, active, quantity left). Only verified sellers on lots
/// managed by this desk and not yet allocated here can be picked.
/// Returns the chosen [OfferItem]; allocation itself is done by the caller.
class SelectSellerLotSheet extends ConsumerWidget {
  final RequirementItem requirement;

  const SelectSellerLotSheet({super.key, required this.requirement});

  static Future<OfferItem?> show(BuildContext context, RequirementItem requirement) {
    // Fresh lots and allocations: a cached offer list can miss new listings.
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(offersProvider.notifier).loadOffers();
    container.read(allocationsProvider(requirement.id).notifier).loadAllocations();
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

  /// Every visible lot of the requirement's commodity (canonical
  /// `commodity_id` via [WorkRepository.computeMatches]: active, valid, stock
  /// left), each with the reason it cannot be allocated, or null when it can.
  /// Selectable lots come first. Lots stay listed when blocked so the broker
  /// sees every matching seller instead of an unexplained empty list.
  static List<SellerCandidate> candidates(
    List<SupplyMatchItem> matches,
    String? brokerId,
    List<AllocationItem> allocations,
  ) {
    final allocatedLots = {
      for (final a in allocations)
        if (a.status != AllocationStatus.cancelled && a.status != AllocationStatus.released) a.availabilityId,
    };
    String? reason(OfferItem o) {
      if (allocatedLots.contains(o.id)) return 'Already allocated to this requirement';
      if (!o.isSellerVerified) return 'Seller not verified';
      if (brokerId == null) return 'Sign in again to allocate';
      // Unassigned global listings are allocatable through broker_allocate_lot
      // (0068), which enforces the rules in the database.
      if (o.brokerId == null || o.brokerId!.isEmpty) return null;
      // Another desk's lot: only that broker may reserve its stock.
      if (o.brokerId != brokerId) return 'Managed by another broker desk';
      return null;
    }

    final list = [for (final m in matches) SellerCandidate(m, reason(m.offer))];
    // Stable: keeps the match-score order within each group.
    return [...list.where((c) => c.canSelect), ...list.where((c) => !c.canSelect)];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersState = ref.watch(offersProvider);
    final allocations = ref.watch(allocationsProvider(requirement.id)).allocations;
    final repo = ref.read(workRepositoryProvider);
    final matches = candidates(
      repo.computeMatches(requirement: requirement, availableOffers: offersState.offers),
      repo.activeBrokerId(),
      allocations,
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
    } else if (offersState.isLoading && matches.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (matches.isEmpty) {
      body = Text(
        'No matching sellers available for ${requirement.commodityName}.',
        key: const ValueKey('no_matching_sellers'),
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
      );
    } else {
      body = Column(
        children: [
          for (final c in matches)
            ListTile(
              key: ValueKey('seller_lot_${c.match.offer.id}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              enabled: c.canSelect,
              leading: Icon(
                c.canSelect ? LucideIcons.shieldCheck : LucideIcons.lock,
                size: 18,
                color: c.canSelect ? AppColors.success : AppColors.textSecondaryLight,
              ),
              title: Text(
                c.match.offer.sellerCompanyName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  '${c.match.offer.commodityName} · ${c.match.offer.lotNumber} · ${c.match.offer.gradeName}',
                  '${c.match.offer.availableQuantity.toStringAsFixed(0)} ${c.match.offer.unitSymbol} · '
                      '${price.format(c.match.offer.askingPrice)}/${c.match.offer.unitSymbol} · '
                      '${c.match.offer.districtName} · ${c.match.offer.status.displayLabel}',
                  if (c.blockedReason != null) c.blockedReason!,
                  if (c.canSelect && (c.match.offer.brokerId?.isEmpty ?? true)) 'Unassigned listing',
                ].join('\n'),
                style: const TextStyle(fontSize: 11.5),
              ),
              trailing: Text(
                c.match.classification.displayLabel,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              onTap: c.canSelect ? () => Navigator.pop(context, c.match.offer) : null,
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
