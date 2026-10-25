import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../deals/presentation/controllers/allocations_controller.dart';
import '../../../deals/presentation/controllers/deals_controller.dart';
import '../../data/work_repository.dart';
import '../../domain/requirement_model.dart';
import '../controllers/requirements_controller.dart';
import '../widgets/negotiate_requirement_sheet.dart';
import '../widgets/select_seller_lot_sheet.dart';

/// Dedicated Requirement Detail Screen following the established Deal Detail navigation pattern.
class RequirementDetailScreen extends ConsumerStatefulWidget {
  final String requirementId;

  const RequirementDetailScreen({
    super.key,
    required this.requirementId,
  });

  @override
  ConsumerState<RequirementDetailScreen> createState() => _RequirementDetailScreenState();
}

class _RequirementDetailScreenState extends ConsumerState<RequirementDetailScreen> {
  /// Fresh copy loaded by id (deep links may arrive before or without the list).
  RequirementItem? _fresh;
  bool _loading = true;
  bool _notFound = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final result = await ref.read(workRepositoryProvider).getRequirementById(widget.requirementId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case WorkSuccess(:final data):
          _fresh = data;
          _notFound = false;
        case WorkError(:final message, :final code):
          _notFound = code == 'NOT_FOUND';
          _loadError = _notFound ? null : message;
        case WorkUnauthorized(:final message):
          _loadError = message;
        case WorkContractPending(:final contractNotice):
          _loadError = contractNotice;
      }
    });
  }

  Future<void> _refreshAll() async {
    await _load();
    if (!mounted) return;
    ref.read(allocationsProvider(widget.requirementId).notifier).loadAllocations();
    ref.read(dealsProvider.notifier).loadDeals();
  }

  static bool _isClosed(RequirementItem r) =>
      r.isExpired ||
      r.status == RequirementStatus.cancelled ||
      r.status == RequirementStatus.fulfilled ||
      r.status == RequirementStatus.expired ||
      r.status == RequirementStatus.fullyAllocated;

  Widget _buildNotice({required IconData icon, required Color color, required String title, required String body}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimaryLight, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pick a verified seller lot, then record the allocation only (no deal).
  /// Stays on this page; the section refreshes after the backend confirms.
  Future<void> _allocateSeller(RequirementItem requirement) async {
    await SelectSellerLotSheet.allocate(context, requirement);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ref.read(allocationsProvider(widget.requirementId).notifier).loadAllocations();
  }

  /// Allocations and deals recorded against this requirement, so the broker can
  /// continue the workflow without losing the requirement link.
  Widget _buildLinkedRecords(BuildContext context, RequirementItem requirement) {
    final allocState = ref.watch(allocationsProvider(requirement.id));
    // Only real deal records: a requirement-level negotiation item has no
    // deal row, and opening it as a deal showed a "Deal record pending" page.
    final deals = ref
        .watch(dealsProvider)
        .deals
        .where((d) => d.requirementId == requirement.id && !d.isRequirementNegotiation)
        .toList();
    final unallocated = !allocState.isLoading && allocState.allocations.isEmpty && deals.isEmpty;
    final canAllocate = unallocated &&
        SelectSellerLotSheet.canAllocate(requirement, ref.read(workRepositoryProvider).activeBrokerId());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Linked Seller Allocations & Deals',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
          ),
          const SizedBox(height: 10),
          if (allocState.isLoading && allocState.allocations.isEmpty)
            const Text('Loading allocations...', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight))
          else if (allocState.allocations.isEmpty && deals.isEmpty) ...[
            Text(
              allocState.errorMessage ?? allocState.contractNotice ?? 'No seller lot has been allocated to this requirement yet.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
            ),
            if (canAllocate) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('allocate_seller_button'),
                onPressed: () => _allocateSeller(requirement),
                icon: const Icon(LucideIcons.userPlus, size: 14),
                label: const Text('Allocate Seller'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
          for (final a in allocState.allocations)
            Padding(
              key: ValueKey('linked_alloc_${a.id}'),
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(LucideIcons.gitCommit, size: 14, color: AppColors.textSecondaryLight),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${a.reference} · ${a.formattedQuantity} · ${a.sellerCompanyName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimaryLight),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(a.status.displayLabel,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
            ),
          for (final d in deals)
            InkWell(
              key: ValueKey('linked_deal_${d.id}'),
              onTap: () => context.push('/deals/${d.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Icon(LucideIcons.handshake, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Deal ${d.ref} · ${d.formattedQuantity} · ${d.sellerCompanyName}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(d.status.displayLabel,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.textSecondaryLight),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(RequirementStatus status) {
    switch (status) {
      case RequirementStatus.open:
        return const Color(0xFF0284C7);
      case RequirementStatus.matching:
        return AppColors.primary;
      case RequirementStatus.partiallyAllocated:
        return const Color(0xFFD97706);
      case RequirementStatus.fullyAllocated:
      case RequirementStatus.fulfilled:
        return AppColors.success;
      case RequirementStatus.expired:
        return AppColors.textDisabled;
      case RequirementStatus.cancelled:
        return AppColors.error;
    }
  }

  void _showCancelDialog(BuildContext context, RequirementItem requirement) {
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          title: const Text('Cancel Requirement Mandate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to cancel mandate ${requirement.ref}? Please provide a formal audit reason.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Cancellation Reason *',
                  hintText: 'Enter reason for cancellation',
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
                    .read(requirementsProvider.notifier)
                    .cancelRequirement(requirement.id, reason);
                if (mounted && success) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Requirement mandate cancelled successfully')),
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

  Widget _buildQuantityRow(String label, double qty, String unit, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                color: isBold ? AppColors.textPrimaryLight : AppColors.textSecondaryLight,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${qty.toStringAsFixed(0)} $unit',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requirementsProvider);
    final cleanId = widget.requirementId.trim().toLowerCase();
    final listed = state.requirements.where((r) {
      return r.id.toLowerCase() == cleanId ||
          r.ref.toLowerCase() == cleanId ||
          r.ref.replaceAll('#', '').toLowerCase() == cleanId;
    }).firstOrNull;
    // The fresh row wins; a row deleted since the list loaded is not shown.
    final requirement = _notFound ? null : (_fresh ?? listed);

    final brokerId = ref.read(workRepositoryProvider).activeBrokerId();
    final isAssigned = requirement != null && brokerId != null && requirement.brokerId == brokerId;
    final isClosed = requirement != null && _isClosed(requirement);
    final canAct = isAssigned && !isClosed;

    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(requirement?.ref ?? 'Requirement Mandate'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/work'),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            tooltip: 'Refresh',
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: _loading && requirement == null
          ? const Center(child: CircularProgressIndicator())
          : requirement == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _loadError != null
                        ? AppEmptyState(
                            icon: LucideIcons.alertCircle,
                            title: 'Could Not Load Requirement',
                            description: _loadError!,
                            actionLabel: 'Retry',
                            onAction: _load,
                          )
                        : AppEmptyState(
                            icon: LucideIcons.fileX,
                            title: 'Requirement Not Found',
                            description:
                                'This requirement may have been deleted, or it is not visible to your broker desk.',
                            actionLabel: 'Return to Work Desk',
                            onAction: () => context.canPop() ? context.pop() : context.go('/work'),
                          ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isAssigned)
                          _buildNotice(
                            icon: LucideIcons.lock,
                            color: AppColors.goldDark,
                            title: 'Not assigned to your desk',
                            body: requirement.brokerId == null
                                ? 'The buyer has not assigned this requirement to a broker. You can view it, but matching and proposals are disabled.'
                                : 'This requirement is assigned to another broker desk. You can view it, but matching and proposals are disabled.',
                          )
                        else if (isClosed)
                          _buildNotice(
                            icon: LucideIcons.archive,
                            color: AppColors.textSecondaryLight,
                            title: 'Requirement closed (${requirement.status.displayLabel})',
                            body: 'This requirement is no longer an active opportunity. Linked deals remain available below.',
                          ),
                        // 1. Status & Urgency Header Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(requirement.status).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  requirement.status.displayLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _getStatusColor(requirement.status),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (requirement.isUrgent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(LucideIcons.clock, size: 12, color: AppColors.error),
                                      SizedBox(width: 4),
                                      Text(
                                        'Urgent Demand',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 2. Commodity & Counterparty Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                requirement.commodityName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Grade: ${requirement.gradeName}',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                              if (requirement.categoryName != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Category: ${requirement.categoryName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                              const Divider(height: 20, color: AppColors.borderLight),
                              Row(
                                children: [
                                  const Icon(LucideIcons.building, size: 16, color: AppColors.textSecondaryLight),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      requirement.buyerCompanyName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimaryLight,
                                      ),
                                    ),
                                  ),
                                  if (requirement.isBuyerVerified)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4, right: 8),
                                      child: Icon(Icons.verified, size: 16, color: AppColors.primary),
                                    ),
                                  // No trust chip when the buyer company is not visible to this desk.
                                  if (requirement.buyerTrustScore > 0) Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${requirement.buyerTrustScore}% Trust',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 3. Complete 7-Quantity Lifecycle Breakdown
                        Container(
                          width: double.infinity,
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
                                  const Expanded(
                                    child: Text(
                                      'Quantity Lifecycle Breakdown',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimaryLight,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${requirement.fulfillmentPercentage}% Fulfilled',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (requirement.fulfillmentPercentage / 100).clamp(0.0, 1.0).toDouble(),
                                  backgroundColor: AppColors.borderLight,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildQuantityRow(
                                '1. Requested Volume',
                                requirement.requestedQuantity,
                                requirement.unitSymbol,
                                AppColors.textPrimaryLight,
                                isBold: true,
                              ),
                              const Divider(height: 12, color: AppColors.borderLight),
                              _buildQuantityRow(
                                '2. Allocated Volume',
                                requirement.allocatedQuantity,
                                requirement.unitSymbol,
                                AppColors.primary,
                              ),
                              _buildQuantityRow(
                                '3. Contracted Volume',
                                requirement.contractedQuantity,
                                requirement.unitSymbol,
                                const Color(0xFF0D9488),
                              ),
                              _buildQuantityRow(
                                '4. Delivered Volume',
                                requirement.deliveredQuantity,
                                requirement.unitSymbol,
                                AppColors.success,
                              ),
                              _buildQuantityRow(
                                '5. Accepted Volume',
                                requirement.acceptedQuantity,
                                requirement.unitSymbol,
                                AppColors.success,
                              ),
                              _buildQuantityRow(
                                '6. Disputed / Rejected',
                                requirement.disputedQuantity,
                                requirement.unitSymbol,
                                AppColors.error,
                              ),
                              const Divider(height: 12, color: AppColors.borderLight),
                              _buildQuantityRow(
                                '7. Remaining Unallocated',
                                requirement.remainingQuantity,
                                requirement.unitSymbol,
                                const Color(0xFFD97706),
                                isBold: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 4. Commercial Terms & Delivery Specs
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Commercial & Delivery Terms',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Target Price', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                                        const SizedBox(height: 3),
                                        Text(
                                          '₹${requirement.targetPrice.toInt()} / ${requirement.unitSymbol}',
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Target Delivery Date', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                                        const SizedBox(height: 3),
                                        Text(
                                          requirement.targetDateFormatted,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(LucideIcons.mapPin, size: 15, color: AppColors.textSecondaryLight),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Delivery Terms: ${requirement.deliveryTerms}',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryLight, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 5. Structured Quality Parameters
                        if (requirement.qualityParameters != null && requirement.qualityParameters!.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Standard Quality Parameters',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: requirement.qualityParameters!.entries.map((entry) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.backgroundLight,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.borderLight),
                                      ),
                                      child: Text(
                                        '${entry.key}: ${entry.value}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimaryLight,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 6. Operational Information & Broker Audit
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Operational Audit & Mandate Records',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Created: ${dateFormat.format(requirement.createdAt)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                              ),
                              if (requirement.brokerId != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Assigned Broker ID: ${requirement.brokerId}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                ),
                              ],
                              if (requirement.notes != null && requirement.notes!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Notes: ${requirement.notes}',
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimaryLight),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 7. Linked allocations and deals
                        _buildLinkedRecords(context, requirement),
                        const SizedBox(height: 20),

                        // 8. Broker Action Buttons (assigned, active requirements only)
                        if (canAct) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              icon: const Icon(LucideIcons.scale, size: 18),
                              label: Text(
                                requirement.isProposed
                                    ? 'View / Amend Commercial Proposal'
                                    : 'Initiate Negotiation & Submit Proposal',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              onPressed: () {
                                NegotiateRequirementSheet.show(
                                  context,
                                  requirement: requirement,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (isAssigned && !isClosed) Row(
                          children: [
                            if (requirement.status != RequirementStatus.cancelled) ...[
                              Expanded(
                                flex: 2,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: Size.zero,
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(color: AppColors.error),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(LucideIcons.ban, size: 16),
                                  label: const Text(
                                    'Cancel Mandate',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onPressed: () => _showCancelDialog(context, requirement),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size.zero,
                                  backgroundColor: requirement.status != RequirementStatus.cancelled && requirement.status != RequirementStatus.fulfilled
                                      ? AppColors.surfaceLight
                                      : AppColors.primary,
                                  foregroundColor: requirement.status != RequirementStatus.cancelled && requirement.status != RequirementStatus.fulfilled
                                      ? AppColors.primary
                                      : Colors.white,
                                  side: requirement.status != RequirementStatus.cancelled && requirement.status != RequirementStatus.fulfilled
                                      ? const BorderSide(color: AppColors.primary)
                                      : BorderSide.none,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(LucideIcons.sparkles, size: 16),
                                label: const Text(
                                  'Find Matching Offers',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () {
                                  // Navigate to Work Desk Match Center tab
                                  context.go('/work?tab=2&reqId=${requirement.id}');
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }
}
