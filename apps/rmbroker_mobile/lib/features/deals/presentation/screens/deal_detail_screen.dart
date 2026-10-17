import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        return const Color(0xFFD97706);
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

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(state.detail?.deal.ref ?? 'Deal Contract'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.history, size: 20),
            tooltip: 'Version History',
            onPressed: () {
              if (state.detail != null) {
                VersionHistorySheet.show(
                  context,
                  dealId: dealId,
                  dealRef: state.detail!.deal.ref,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            tooltip: 'Refresh',
            onPressed: () => ref.read(dealDetailProvider(dealId).notifier).loadDetail(),
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
              : state.detail == null
                  ? AppEmptyState(
                      icon: LucideIcons.fileX,
                      title: 'Deal Record Pending',
                      description: state.contractNotice ??
                          'Deal information is currently synchronizing with authoritative backend.',
                    )
                  : _buildDealBody(context, ref, state.detail!, currencyFormat, dateFormat),
    );
  }

  Widget _buildDealBody(
    BuildContext context,
    WidgetRef ref,
    DealDetailItem detail,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    final deal = detail.deal;
    final statusColor = _getStatusColor(deal.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Finalized Booking Reference Banner
          if (deal.bookingReference != null || deal.status == DealStatus.finalized) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 14),
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
                        Text(
                          'Contract terms immutable & locked with trade exchange.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Header Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        deal.status.displayLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Text(
                        'Version ${deal.latestVersionNumber}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      deal.ref,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  deal.commodityName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                if (deal.gradeName != null && deal.gradeName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Grade: ${deal.gradeName}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Key Commercial KPIs
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'Agreed Volume',
                        deal.formattedQuantity,
                        AppColors.textPrimaryLight,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricTile(
                        'Rate',
                        '${currencyFormat.format(deal.agreedPrice)} / ${deal.unitSymbol}',
                        AppColors.textPrimaryLight,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricTile(
                        'Total Value',
                        currencyFormat.format(deal.totalValuation),
                        AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Counterparties Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.users, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Counterparties',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                _buildPartyInfoTile('Buyer Enterprise', deal.buyerCompanyName, LucideIcons.building2),
                const SizedBox(height: 10),
                _buildPartyInfoTile('Seller Enterprise', deal.sellerCompanyName, LucideIcons.store),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Dual Confirmation Status Card (CRITICAL PER SPRINT SCOPE)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.checkSquare, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Party Confirmation Verification',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                _buildConfirmationRow(
                  'Buyer Confirmation',
                  detail.confirmations.buyerConfirmed,
                  detail.confirmations.buyerConfirmedAt != null
                      ? dateFormat.format(detail.confirmations.buyerConfirmedAt!)
                      : 'Pending buyer acceptance of v${detail.confirmations.latestVersionNumber}',
                ),
                const SizedBox(height: 10),
                _buildConfirmationRow(
                  'Seller Confirmation',
                  detail.confirmations.sellerConfirmed,
                  detail.confirmations.sellerConfirmedAt != null
                      ? dateFormat.format(detail.confirmations.sellerConfirmedAt!)
                      : 'Pending seller acceptance of v${detail.confirmations.latestVersionNumber}',
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        detail.confirmations.canFinalize
                            ? LucideIcons.checkCircle2
                            : LucideIcons.info,
                        size: 15,
                        color: detail.confirmations.canFinalize
                            ? AppColors.success
                            : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          detail.confirmations.canFinalize
                              ? 'Both parties have formally confirmed terms. Deal is ready for booking lock.'
                              : 'Per business rules, deal cannot be marked Finalized until both Buyer and Seller confirm the exact same version terms.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: detail.confirmations.canFinalize
                                ? AppColors.success
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Record Confirmation Action Button
                if (deal.status.isOperational && !detail.confirmations.canFinalize) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(LucideIcons.checkSquare, size: 15, color: AppColors.primary),
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
          const SizedBox(height: 14),

          // Contract Specifications Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.fileText, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Contract Terms & Logistics',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
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
          const SizedBox(height: 14),

          // Broker Commission & Settlement Ledger Card (Sprint RB-FL-11)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(LucideIcons.indianRupee, size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Brokerage Commission Ledger',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '₹${detail.brokerCommissionRate.toStringAsFixed(0)} / ${detail.commissionBasis}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
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
          const SizedBox(height: 14),

          // Audit Traceability Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.gitCommit, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Traceability & Audit Record',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (deal.allocationReference != null)
                  _buildTermRow('Linked Allocation', deal.allocationReference!),
                _buildTermRow('Created On', dateFormat.format(deal.createdAt)),
                _buildTermRow('RMBroker Mediation', 'Authorized Intermediary Record'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Operational Workflow Actions
          if (deal.status.isOperational) ...[
            // 1. Finalize Contract (Pre-flight gate unlocked)
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

            // 2. Propose Terms Amendment (Negotiation Engine)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: detail.confirmations.canFinalize
                      ? AppColors.backgroundLight
                      : AppColors.primary,
                  foregroundColor: detail.confirmations.canFinalize
                      ? AppColors.primary
                      : Colors.white,
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
                    fontSize: 13,
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

            // 3. Inspect Version History
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.borderLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(LucideIcons.history, size: 16, color: AppColors.textPrimaryLight),
                label: const Text(
                  'Inspect Terms History & Diffs',
                  style: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
                onPressed: () => VersionHistorySheet.show(
                  context,
                  dealId: dealId,
                  dealRef: deal.ref,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 4. Cancel Deal
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(LucideIcons.ban, size: 16, color: AppColors.error),
                label: const Text(
                  'Cancel Deal Record',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                onPressed: () => _showCancelDealDialog(context, ref, deal),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            // For Finalized / Cancelled deals, allow viewing Version History
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.borderLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(LucideIcons.history, size: 16, color: AppColors.textPrimaryLight),
                label: const Text(
                  'Inspect Version History & Diffs',
                  style: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w600),
                ),
                onPressed: () => VersionHistorySheet.show(
                  context,
                  dealId: dealId,
                  dealRef: deal.ref,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildPartyInfoTile(String role, String companyName, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
              Text(
                companyName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationRow(String label, bool isConfirmed, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isConfirmed ? LucideIcons.checkCircle2 : LucideIcons.clock,
          size: 16,
          color: isConfirmed ? AppColors.success : const Color(0xFFD97706),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label: ${isConfirmed ? "Confirmed" : "Pending"}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isConfirmed ? AppColors.success : const Color(0xFF92400E),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
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
