import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../domain/deal_model.dart';
import '../controllers/deal_detail_controller.dart';
import '../controllers/deals_controller.dart';
import '../../../commission/domain/commission_model.dart';
import '../../../commission/presentation/widgets/deal_commission_sheet.dart';
import '../widgets/finalize_deal_dialog.dart';
import '../widgets/negotiate_terms_sheet.dart';
import '../widgets/record_party_confirmation_dialog.dart';
import '../widgets/version_history_sheet.dart';

const Color _pendingColor = Color(0xFFD97706);

class DealDetailScreen extends ConsumerWidget {
  final String dealId;

  const DealDetailScreen({
    super.key,
    required this.dealId,
  });

  Color _getStatusColor(DealStatus status) {
    switch (status) {
      case DealStatus.draft:
        return AppColors.textSecondaryLight;
      case DealStatus.negotiation:
        return _pendingColor;
      case DealStatus.awaitingBuyerConfirmation:
      case DealStatus.awaitingSellerConfirmation:
        return const Color(0xFF7C3AED);
      case DealStatus.readyToFinalize:
        return AppColors.primary;
      case DealStatus.finalized:
      case DealStatus.inFulfillment:
      case DealStatus.completed:
        return AppColors.success;
      case DealStatus.cancelled:
      case DealStatus.disputed:
        return AppColors.error;
    }
  }

  void _showCancelDealDialog(BuildContext context, WidgetRef ref, DealItem deal) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          title: const Text('Cancel Deal Contract', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to cancel deal ${deal.ref}? Any linked supply allocations will be safely released back to available inventory.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Audit Cancellation Reason *',
                  hintText: 'Enter formal reason for audit logs',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext),
              child: const Text('Keep Active'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.length < 3) return;
                Navigator.pop(dlgContext);
                final success = await ref
                    .read(dealDetailProvider(dealId).notifier)
                    .cancelDeal(reason);
                if (context.mounted && success) {
                  ref.read(dealsProvider.notifier).loadDeals();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deal cancelled and inventory restored to stock')),
                  );
                }
              },
              child: const Text('Confirm Cancel', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dealDetailProvider(dealId));
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final detail = state.detail;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(detail?.deal.ref ?? 'Deal Contract'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.history, size: 20),
            tooltip: 'Version History',
            onPressed: () {
              if (detail != null) {
                VersionHistorySheet.show(
                  context,
                  dealId: dealId,
                  dealRef: detail.deal.ref,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            tooltip: 'Refresh',
            onPressed: () => ref.read(dealDetailProvider(dealId).notifier).loadDetail(),
          ),
          if (detail != null && detail.deal.status.isOperational)
            PopupMenuButton<String>(
              key: const ValueKey('deal_more_menu'),
              icon: const Icon(LucideIcons.moreVertical, size: 20),
              onSelected: (v) {
                if (v == 'cancel') _showCancelDealDialog(context, ref, detail.deal);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(LucideIcons.ban, size: 16, color: AppColors.error),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Cancel Deal Record',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppEmptyState(
                      icon: LucideIcons.alertTriangle,
                      title: 'Error Loading Deal',
                      description: state.errorMessage!,
                    ),
                  ),
                )
              : detail == null
                  ? AppEmptyState(
                      icon: LucideIcons.fileX,
                      title: 'Deal Record Pending',
                      description: state.contractNotice ??
                          'Deal information is currently synchronizing with authoritative backend.',
                    )
                  : _buildDealBody(context, ref, detail, currencyFormat, dateFormat),
    );
  }

  static BoxDecoration get _cardDecoration => BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      );

  Widget _buildDealBody(
    BuildContext context,
    WidgetRef ref,
    DealDetailItem detail,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    final deal = detail.deal;
    final statusColor = _getStatusColor(deal.status);
    final canRecordAcceptance = deal.status.isOperational && !detail.confirmations.canFinalize;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Finalized Booking Reference Banner
          if (deal.bookingReference != null || deal.status == DealStatus.finalized) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.shieldCheck, color: AppColors.success, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FINALIZED BOOKING REFERENCE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          deal.bookingReference ?? deal.ref,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimaryLight,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Text(
                          'Contract terms immutable & locked with trade exchange.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 1. Buyer | Seller with one confirmation chip each
          Container(
            key: const ValueKey('deal_parties_card'),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            decoration: _cardDecoration,
            child: Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildPartyColumn(
                          role: 'Buyer',
                          companyName: deal.buyerCompanyName,
                          icon: LucideIcons.building2,
                          iconColor: const Color(0xFF2563EB),
                          confirmed: detail.confirmations.buyerConfirmed,
                          chipKey: const ValueKey('buyer_confirmation_chip'),
                        ),
                      ),
                      const VerticalDivider(width: 20, thickness: 1, color: AppColors.borderLight),
                      Expanded(
                        child: _buildPartyColumn(
                          role: 'Seller',
                          companyName: deal.sellerCompanyName,
                          icon: LucideIcons.store,
                          iconColor: AppColors.primary,
                          confirmed: detail.confirmations.sellerConfirmed,
                          chipKey: const ValueKey('seller_confirmation_chip'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (canRecordAcceptance) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const ValueKey('record_acceptance_button'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(LucideIcons.checkSquare, size: 14, color: AppColors.primary),
                      label: const Text(
                        'Record Counterparty Acceptance',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                      onPressed: () => RecordPartyConfirmationDialog.show(
                        context,
                        dealId: dealId,
                        detail: detail,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Deal summary
          Container(
            key: const ValueKey('deal_summary_card'),
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deal.commodityName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          if (deal.gradeName != null && deal.gradeName!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Grade: ${deal.gradeName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bounded so the chips wrap under each other on narrow screens.
                    Flexible(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.end,
                        children: [
                          _chip(deal.status.displayLabel, statusColor),
                          _chip('Version ${deal.latestVersionNumber}', AppColors.textSecondaryLight),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(LucideIcons.package, 'Agreed Volume', deal.formattedQuantity,
                            AppColors.textPrimaryLight),
                      ),
                      const VerticalDivider(width: 12, color: AppColors.borderLight),
                      Expanded(
                        child: _buildMetricTile(
                          LucideIcons.coins,
                          'Rate',
                          '${currencyFormat.format(deal.agreedPrice)} / ${deal.unitSymbol}',
                          AppColors.textPrimaryLight,
                        ),
                      ),
                      const VerticalDivider(width: 12, color: AppColors.borderLight),
                      Expanded(
                        child: _buildMetricTile(LucideIcons.calculator, 'Total Value',
                            currencyFormat.format(deal.totalValuation), AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Negotiation details (navigation)
          _SectionHeaderCard(
            key: const ValueKey('section_negotiation'),
            icon: LucideIcons.messageSquareText,
            title: 'Negotiation Details',
            subtitle: 'Latest offer, counter offers and messages',
            trailing: const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textSecondaryLight),
            onTap: () => deal.requirementId.isNotEmpty
                ? context.push('/requirements/${deal.requirementId}')
                : VersionHistorySheet.show(context, dealId: dealId, dealRef: deal.ref),
          ),
          const SizedBox(height: 10),

          // 4. Collapsible sections (each collapsed whenever the page opens)
          _AccordionCard(
            key: const ValueKey('section_terms'),
            icon: LucideIcons.fileText,
            title: 'Contract Terms & Logistics',
            subtitle: 'Price basis, delivery, payment terms, packaging etc.',
            child: Column(
              children: [
                _buildTermRow('Price Basis', deal.priceBasis),
                _buildTermRow('Delivery Location', deal.deliveryLocation ?? 'FOR Mandi Warehouse'),
                _buildTermRow('Delivery Terms', detail.deliveryTerms),
                _buildTermRow('Payment Terms', detail.paymentTerms),
                _buildTermRow('Packaging Type', detail.packagingType),
                _buildTermRow(
                  'Broker Commission',
                  '₹${detail.brokerCommissionRate.toInt()} / ${detail.commissionBasis}',
                ),
                if (detail.notes != null && detail.notes!.isNotEmpty)
                  _buildTermRow('Broker Notes', detail.notes!),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _AccordionCard(
            key: const ValueKey('section_commission'),
            icon: LucideIcons.indianRupee,
            title: 'Brokerage Commission Ledger',
            subtitle: 'Commission details and payment ledger',
            child: Column(
              children: [
                _buildTermRow(
                  'Eligible Commission',
                  '₹${(deal.agreedQuantity * detail.brokerCommissionRate).toStringAsFixed(2)} (Delivery basis)',
                ),
                _buildTermRow('Fiduciary Status', 'Authoritative Broker Ledger Active'),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(LucideIcons.fileSpreadsheet, size: 16, color: AppColors.primary),
                    label: const Text(
                      'View Commission Breakdown & Payment Ledger',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                    onPressed: () {
                      final record = CommissionRecord(
                        dealId: deal.id,
                        dealReference: deal.ref,
                        bookingReference: deal.bookingReference,
                        commodityName: deal.commodityName,
                        gradeName: deal.gradeName,
                        buyerCompanyName: deal.buyerCompanyName,
                        sellerCompanyName: deal.sellerCompanyName,
                        agreedRatePerMT: detail.brokerCommissionRate,
                        commissionBasis: detail.commissionBasis,
                        quantities: CommissionQuantityBreakdown(
                          contractedQuantity: deal.agreedQuantity,
                          dispatchedQuantity: deal.agreedQuantity,
                          deliveredQuantity: deal.agreedQuantity,
                          acceptedQuantity: deal.agreedQuantity,
                          unitSymbol: deal.unitSymbol,
                        ),
                        grossRawMaterialValue: deal.totalValuation,
                        calculatedCommission: deal.agreedQuantity * detail.brokerCommissionRate,
                        eligibleCommission: deal.agreedQuantity * detail.brokerCommissionRate,
                        invoicedAmount: deal.agreedQuantity * detail.brokerCommissionRate,
                        paidAmount: 0.0,
                        outstandingAmount: deal.agreedQuantity * detail.brokerCommissionRate,
                        disputedAmount: 0.0,
                        status: CommissionStatus.eligible,
                        createdAt: deal.createdAt,
                        updatedAt: DateTime.now(),
                      );
                      DealCommissionSheet.show(context, record: record);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _AccordionCard(
            key: const ValueKey('section_audit'),
            icon: LucideIcons.clock,
            title: 'Traceability & Audit Record',
            subtitle: 'Created on ${dateFormat.format(deal.createdAt)}',
            child: Column(
              children: [
                if (deal.allocationReference != null)
                  _buildTermRow('Linked Allocation', deal.allocationReference!),
                _buildTermRow('Created On', dateFormat.format(deal.createdAt)),
                _buildTermRow('RMBroker Mediation', 'Authorized Intermediary Record'),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 5. Actions (end of the scroll, never over content)
          if (deal.status.isOperational) ...[
            if (detail.confirmations.canFinalize) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(LucideIcons.lock, size: 18, color: Colors.white),
                  label: const Text(
                    'Pre-Flight Finalization Gate (Lock Contract)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                  onPressed: () => FinalizeDealDialog.show(
                    context,
                    dealId: dealId,
                    detail: detail,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const ValueKey('negotiate_terms_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: detail.confirmations.canFinalize ? AppColors.surfaceLight : AppColors.primary,
                  foregroundColor: detail.confirmations.canFinalize ? AppColors.primary : Colors.white,
                  elevation: detail.confirmations.canFinalize ? 0 : 1,
                  side: detail.confirmations.canFinalize ? const BorderSide(color: AppColors.primary) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(
                  LucideIcons.gitPullRequest,
                  size: 17,
                  color: detail.confirmations.canFinalize ? AppColors.primary : Colors.white,
                ),
                label: Text(
                  'Negotiate Terms (Propose v${deal.latestVersionNumber + 1})',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: detail.confirmations.canFinalize ? AppColors.primary : Colors.white,
                  ),
                ),
                onPressed: () => NegotiateTermsSheet.show(
                  context,
                  dealId: dealId,
                  currentDetail: detail,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              key: const ValueKey('terms_history_button'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surfaceLight,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(LucideIcons.history, size: 16, color: AppColors.primary),
              label: const Text(
                'Inspect Terms History & Diffs',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              onPressed: () => VersionHistorySheet.show(
                context,
                dealId: dealId,
                dealRef: deal.ref,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color, {Key? key, IconData? icon}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyColumn({
    required String role,
    required String companyName,
    required IconData icon,
    required Color iconColor,
    required bool confirmed,
    required Key chipKey,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
              Text(
                companyName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
              ),
              const SizedBox(height: 6),
              _chip(
                confirmed ? 'Confirmed' : 'Pending',
                confirmed ? AppColors.success : _pendingColor,
                key: chipKey,
                icon: confirmed ? LucideIcons.checkCircle2 : LucideIcons.clock,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(IconData icon, String label, String value, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondaryLight),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: valueColor)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTermRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon, title and subtitle row used by every section card.
class _SectionHeaderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final Widget? body;

  const _SectionHeaderCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: DealDetailScreen._cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    trailing,
                  ],
                ),
              ),
            ),
            ?body,
          ],
        ),
      ),
    );
  }
}

/// A section that starts collapsed each time the page opens; its expanded
/// state is local, so sections never affect one another.
class _AccordionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _AccordionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  State<_AccordionCard> createState() => _AccordionCardState();
}

class _AccordionCardState extends State<_AccordionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return _SectionHeaderCard(
      icon: widget.icon,
      title: widget.title,
      subtitle: widget.subtitle,
      onTap: () => setState(() => _expanded = !_expanded),
      trailing: AnimatedRotation(
        turns: _expanded ? 0.5 : 0,
        duration: const Duration(milliseconds: 180),
        child: const Icon(LucideIcons.chevronDown, size: 20, color: AppColors.textSecondaryLight),
      ),
      body: _expanded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  widget.child,
                ],
              ),
            )
          : null,
    );
  }
}
