import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/features/directory/utils/phone_utils.dart';
import 'package:rmbroker_mobile/features/search/domain/search_result.dart';

/// Grouped and filtered search results display.
class SearchResultsView extends StatelessWidget {
  final GlobalSearchResults results;
  final SearchEntityType activeFilter;
  final String query;

  const SearchResultsView({
    super.key,
    required this.results,
    required this.activeFilter,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 1. Contacts Section
        if ((activeFilter == SearchEntityType.all ||
                activeFilter == SearchEntityType.contacts) &&
            results.contacts.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'BUYERS & SELLERS',
            count: results.contacts.length,
            icon: LucideIcons.users,
          ),
          ...results.contacts.map((contact) => _buildContactCard(context, contact)),
          const SizedBox(height: 16),
        ],

        // 2. Materials Section
        if ((activeFilter == SearchEntityType.all ||
                activeFilter == SearchEntityType.materials) &&
            results.materials.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'RAW MATERIALS & COMMODITIES',
            count: results.materials.length,
            icon: LucideIcons.package,
          ),
          ...results.materials.map((mat) => _buildMaterialCard(context, mat)),
          const SizedBox(height: 16),
        ],

        // 3. Requirements Section
        if ((activeFilter == SearchEntityType.all ||
                activeFilter == SearchEntityType.requirements) &&
            results.requirements.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'BUYER REQUIREMENTS',
            count: results.requirements.length,
            icon: LucideIcons.clipboardList,
          ),
          ...results.requirements.map(
            (req) => _buildRequirementCard(context, req, currencyFormatter),
          ),
          const SizedBox(height: 16),
        ],

        // 4. Offers Section
        if ((activeFilter == SearchEntityType.all ||
                activeFilter == SearchEntityType.offers) &&
            results.offers.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'SELLER OFFERS (AVAILABILITY)',
            count: results.offers.length,
            icon: LucideIcons.layers,
          ),
          ...results.offers.map(
            (offer) => _buildOfferCard(context, offer, currencyFormatter),
          ),
          const SizedBox(height: 16),
        ],

        // 5. Deals Section
        if ((activeFilter == SearchEntityType.all ||
                activeFilter == SearchEntityType.deals) &&
            results.deals.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'DEALS & NEGOTIATIONS',
            count: results.deals.length,
            icon: LucideIcons.handshake,
          ),
          ...results.deals.map(
            (deal) => _buildDealCard(context, deal, currencyFormatter),
          ),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariantLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, SearchContactItem contact) {
    final isBuyer = contact.isBuyer;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      color: AppColors.surfaceLight,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.go('/directory');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar Monogram
              CircleAvatar(
                radius: 20,
                backgroundColor: isBuyer
                    ? AppColors.primaryContainer.withValues(alpha: 0.4)
                    : AppColors.goldMuted.withValues(alpha: 0.2),
                child: Text(
                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : 'C',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isBuyer ? AppColors.primaryDark : AppColors.goldDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Contact Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            contact.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isBuyer
                                ? AppColors.primaryContainer.withValues(alpha: 0.5)
                                : AppColors.goldMuted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            contact.role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isBuyer
                                  ? AppColors.primaryDark
                                  : AppColors.goldDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.companyName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (contact.city != null && contact.city!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.mapPin,
                            size: 11,
                            color: AppColors.textDisabled,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            contact.city!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Action Buttons: Call & WhatsApp
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.phone, size: 18),
                    color: AppColors.primary,
                    tooltip: 'Call contact dialler',
                    onPressed: () => PhoneUtils.launchCall(context, contact.mobile),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.messageCircle, size: 18),
                    color: AppColors.success,
                    tooltip: 'Open WhatsApp chat',
                    onPressed: () => PhoneUtils.launchWhatsApp(context, contact.mobile),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialCard(BuildContext context, SearchMaterialItem mat) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      color: AppColors.surfaceLight,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.go('/work');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    mat.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  if (mat.code != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariantLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        mat.code!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                ],
              ),
              if (mat.categoryName != null) ...[
                const SizedBox(height: 3),
                Text(
                  mat.categoryName!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
              if (mat.grades.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: mat.grades.take(4).map((grade) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        grade,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementCard(
    BuildContext context,
    SearchRequirementItem req,
    NumberFormat currencyFormatter,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      color: AppColors.surfaceLight,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.go('/work');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    req.commodityName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${req.quantity.toInt()} ${req.unitSymbol}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    req.buyerCompanyName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  Text(
                    'Target: ${currencyFormatter.format(req.targetPrice)}/${req.unitSymbol}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfferCard(
    BuildContext context,
    SearchOfferItem offer,
    NumberFormat currencyFormatter,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      color: AppColors.surfaceLight,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.go('/work');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    offer.commodityName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${offer.availableQuantity.toInt()} ${offer.unitSymbol}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.goldDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    offer.sellerCompanyName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  Text(
                    'Ask: ${currencyFormatter.format(offer.askingPrice)}/${offer.unitSymbol}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDealCard(
    BuildContext context,
    SearchDealItem deal,
    NumberFormat currencyFormatter,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      color: AppColors.surfaceLight,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.go('/deals');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    deal.dealRef,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariantLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      deal.status.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${deal.buyerName} ⇄ ${deal.sellerName}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${deal.agreedQuantity.toInt()} MT @ ${currencyFormatter.format(deal.agreedPrice)}/MT',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
