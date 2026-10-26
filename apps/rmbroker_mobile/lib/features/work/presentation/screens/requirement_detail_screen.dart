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
import '../../domain/requirement_negotiation_model.dart';
import '../controllers/requirements_controller.dart';
import '../widgets/detail_accordion_card.dart';
import '../widgets/negotiate_requirement_sheet.dart';
import '../widgets/select_seller_lot_sheet.dart';

/// Requirement Details: compact header and summary, seven collapsible
/// sections (all collapsed on entry) and a sticky action bar.
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

  /// Recorded proposal rounds (deal versions) for Activity History; loaded
  /// once with the page, never on section expansion.
  List<NegotiationRoundItem> _rounds = const [];

  static const Color _navy = AppColors.primaryNavy;
  static const Color _blue = Color(0xFF2563EB);
  static const Color _green = Color(0xFF059669);
  static const Color _amber = Color(0xFFD97706);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _slate = Color(0xFF475569);
  static const Color _pink = Color(0xFFBE185D);

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
    final repo = ref.read(workRepositoryProvider);
    final result = await repo.getRequirementById(widget.requirementId);
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
    // Rounds are only readable by the assigned broker (the repository rejects others).
    if (result is WorkSuccess<RequirementItem> &&
        result.data.brokerId != null &&
        result.data.brokerId == repo.activeBrokerId()) {
      _loadRounds(repo);
    }
  }

  Future<void> _loadRounds(WorkRepository repo) async {
    try {
      final res = await repo.getRequirementNegotiationDetails(widget.requirementId);
      if (!mounted) return;
      if (res is WorkSuccess<RequirementNegotiationData>) setState(() => _rounds = res.data.rounds);
    } catch (_) {
      // Activity History then shows only the creation event.
    }
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
      margin: const EdgeInsets.only(bottom: 10),
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

  // --------------------------------------------------------------------------
  // Seller Allocation & Deals
  // --------------------------------------------------------------------------

  Widget _buildSellerSection(RequirementItem requirement) {
    final allocState = ref.watch(allocationsProvider(requirement.id));
    // Only real deal records: a requirement-level negotiation item has no
    // deal row, and opening it as a deal showed a "Deal record pending" page.
    final deals = ref
        .watch(dealsProvider)
        .deals
        .where((d) => d.requirementId == requirement.id && !d.isRequirementNegotiation)
        .toList();
    final allocations = allocState.allocations;
    final empty = allocations.isEmpty && deals.isEmpty;
    final unallocated = !allocState.isLoading && empty;
    final canAllocate = unallocated &&
        SelectSellerLotSheet.canAllocate(requirement, ref.read(workRepositoryProvider).activeBrokerId());

    final String summary;
    if (allocState.isLoading && empty) {
      summary = 'Loading allocations...';
    } else if (empty) {
      summary = allocState.errorMessage ?? allocState.contractNotice ?? 'No seller allocated yet';
    } else {
      summary = [
        if (allocations.isNotEmpty) '${allocations.length} allocation${allocations.length == 1 ? '' : 's'}',
        if (deals.isNotEmpty) '${deals.length} deal${deals.length == 1 ? '' : 's'}',
      ].join(' · ');
    }

    return DetailAccordionCard(
      sectionKey: 'seller',
      icon: LucideIcons.users,
      tint: _purple,
      title: 'Seller Allocation & Deals',
      summary: summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (allocState.isLoading && empty)
            const Text('Loading allocations...', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight))
          else if (empty) ...[
            const Icon(LucideIcons.users, size: 30, color: AppColors.textSecondaryLight),
            const SizedBox(height: 6),
            Text(
              allocState.errorMessage ?? allocState.contractNotice ?? 'No seller lot has been allocated to this requirement yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
            ),
            if (canAllocate) ...[
              const SizedBox(height: 4),
              const Text(
                'Allocate a seller to start negotiations and move this requirement forward.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('allocate_seller_button'),
                onPressed: () => _allocateSeller(requirement),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Allocate Seller'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
          for (final a in allocations)
            Padding(
              key: ValueKey('linked_alloc_${a.id}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
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
                padding: const EdgeInsets.symmetric(vertical: 6),
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

  // --------------------------------------------------------------------------
  // Activity History: only recorded events (creation + saved proposal rounds)
  // --------------------------------------------------------------------------

  List<({String title, DateTime at, String detail})> _activityEvents(RequirementItem r) {
    final money = NumberFormat.decimalPattern('en_IN');
    final events = <({String title, DateTime at, String detail})>[
      (title: 'Requirement Created', at: r.createdAt, detail: 'Mandate recorded for ${r.formattedRequestedQuantity}.'),
      for (final round in _rounds)
        (
          title: round.isBroker ? 'Proposal v${round.versionNumber} sent to buyer' : 'Buyer counter-offer v${round.versionNumber}',
          at: round.createdAt,
          detail: '₹${money.format(round.rate.round())} / ${r.unitSymbol} · ${round.quantity.toStringAsFixed(0)} ${r.unitSymbol}',
        ),
    ];
    events.sort((a, b) => b.at.compareTo(a.at));
    return events;
  }

  Widget _buildActivitySection(RequirementItem r, DateFormat dateFormat) {
    final events = _activityEvents(r);
    final latest = events.first;
    return DetailAccordionCard(
      sectionKey: 'activity',
      icon: LucideIcons.clock,
      tint: _amber,
      title: 'Activity History',
      summary: 'Latest: ${latest.title} (${DateFormat('dd MMM yyyy').format(latest.at)})',
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++)
            IntrinsicHeight(
              key: ValueKey('activity_event_$i'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: i == 0 ? AppColors.primary : AppColors.textDisabled,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i < events.length - 1)
                        const Expanded(child: VerticalDivider(width: 12, thickness: 1.5, color: AppColors.borderLight)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(events[i].title,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
                          Text(dateFormat.format(events[i].at),
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight)),
                          Text(events[i].detail,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Shared row builders
  // --------------------------------------------------------------------------

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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, String value, Color tint) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tint)),
              ],
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

  // --------------------------------------------------------------------------
  // Bottom action bar (same actions and conditions as before)
  // --------------------------------------------------------------------------

  Widget? _buildActionBar(RequirementItem requirement, bool canAct, bool showSecondary) {
    if (!canAct && !showSecondary) return null;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: const Border(top: BorderSide(color: AppColors.borderLight)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canAct)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const ValueKey('req_action_proposal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(LucideIcons.scale, size: 18),
                  label: Text(
                    requirement.isProposed ? 'View / Amend Proposal' : 'Initiate Negotiation & Submit Proposal',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  onPressed: () => NegotiateRequirementSheet.show(context, requirement: requirement),
                ),
              ),
            if (canAct && showSecondary) const SizedBox(height: 8),
            if (showSecondary)
              Row(
                children: [
                  if (requirement.status != RequirementStatus.cancelled) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('req_action_cancel'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
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
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('req_action_matches'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.zero,
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(LucideIcons.sparkles, size: 16),
                      label: const Text(
                        'Find Matching Offers',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Navigate to Work Desk Match Center tab
                      onPressed: () => context.go('/work?tab=2&reqId=${requirement.id}'),
                    ),
                  ),
                ],
              ),
          ],
        ),
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
        title: const Text('Requirement Details'),
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
      bottomNavigationBar: requirement == null ? null : _buildActionBar(requirement, canAct, canAct),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildSections(requirement, isAssigned, isClosed, brokerId, dateFormat),
                    ),
                  ),
                ),
    );
  }

  List<Widget> _buildSections(
    RequirementItem requirement,
    bool isAssigned,
    bool isClosed,
    String? brokerId,
    DateFormat dateFormat,
  ) {
    final statusColor = _getStatusColor(requirement.status);
    final money = NumberFormat.decimalPattern('en_IN');
    final price = '₹${money.format(requirement.targetPrice.round())} / ${requirement.unitSymbol}';
    final hasQuality = requirement.qualityParameters != null && requirement.qualityParameters!.isNotEmpty;

    final String assignment;
    if (requirement.brokerId == null) {
      assignment = 'Not assigned to a broker';
    } else if (requirement.brokerId == brokerId) {
      assignment = 'Your broker desk';
    } else {
      assignment = 'Another broker desk';
    }

    return [
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

      // Header: status · urgency · Req ID · created
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              requirement.status.displayLabel,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
            ),
          ),
          if (requirement.isUrgent) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Urgent Demand',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  requirement.ref,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy),
                ),
                Text(
                  'Created ${dateFormat.format(requirement.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),

      // Commodity summary card
      Container(
        key: const ValueKey('req_summary_card'),
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(LucideIcons.wheat, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requirement.commodityName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy),
                      ),
                      Text(
                        'Grade: ${requirement.gradeName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                      ),
                      if (requirement.categoryName != null)
                        Text(
                          'Category: ${requirement.categoryName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: AppColors.borderLight),
            Row(
              children: [
                const Icon(LucideIcons.building2, size: 16, color: AppColors.textSecondaryLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    requirement.buyerCompanyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
                  ),
                ),
                if (requirement.isBuyerVerified)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, right: 4),
                    child: Icon(Icons.verified, size: 16, color: AppColors.primary),
                  ),
                // No trust chip when the buyer company is not visible to this desk.
                if (requirement.buyerTrustScore > 0)
                  Text(
                    '${requirement.buyerTrustScore}% Trust',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
                  ),
              ],
            ),
          ],
        ),
      ),

      // 1. Quantity Breakdown
      DetailAccordionCard(
        sectionKey: 'quantity',
        icon: LucideIcons.chartColumn,
        tint: _blue,
        title: 'Quantity Breakdown',
        summary:
            'Requested: ${requirement.formattedRequestedQuantity}  |  Fulfilled: ${requirement.fulfillmentPercentage}%',
        trailingLabel: '${requirement.fulfillmentPercentage}% Fulfilled',
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (requirement.fulfillmentPercentage / 100).clamp(0.0, 1.0).toDouble(),
                backgroundColor: AppColors.borderLight,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            _buildQuantityRow('1. Requested Volume', requirement.requestedQuantity, requirement.unitSymbol,
                AppColors.textPrimaryLight, isBold: true),
            const Divider(height: 12, color: AppColors.borderLight),
            _buildQuantityRow(
                '2. Allocated Volume', requirement.allocatedQuantity, requirement.unitSymbol, AppColors.primary),
            _buildQuantityRow('3. Contracted Volume', requirement.contractedQuantity, requirement.unitSymbol,
                const Color(0xFF0D9488)),
            _buildQuantityRow(
                '4. Delivered Volume', requirement.deliveredQuantity, requirement.unitSymbol, AppColors.success),
            _buildQuantityRow(
                '5. Accepted Volume', requirement.acceptedQuantity, requirement.unitSymbol, AppColors.success),
            _buildQuantityRow(
                '6. Disputed / Rejected', requirement.disputedQuantity, requirement.unitSymbol, AppColors.error),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _amber.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: _buildQuantityRow('Remaining Unallocated', requirement.remainingQuantity, requirement.unitSymbol,
                  _amber, isBold: true),
            ),
          ],
        ),
      ),

      // 2. Price & Delivery
      DetailAccordionCard(
        sectionKey: 'price',
        icon: LucideIcons.indianRupee,
        tint: _green,
        title: 'Price & Delivery',
        summary: '$price  |  ${requirement.targetDateFormatted}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _tile(LucideIcons.indianRupee, 'Target Price', price, _green)),
                const SizedBox(width: 8),
                Expanded(
                    child: _tile(LucideIcons.calendar, 'Target Delivery Date', requirement.targetDateFormatted, _blue)),
              ],
            ),
            const SizedBox(height: 8),
            _tile(
              LucideIcons.mapPin,
              'Delivery Terms',
              requirement.deliveryTerms.trim().isEmpty ? 'Not specified' : requirement.deliveryTerms,
              _slate,
            ),
            if (hasQuality) ...[
              const SizedBox(height: 10),
              const Text('Quality Parameters',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _navy)),
              const SizedBox(height: 6),
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
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),

      // 3. Activity History
      _buildActivitySection(requirement, dateFormat),

      // 4. Seller Allocation & Deals
      _buildSellerSection(requirement),

      // 5. Buyer Details
      DetailAccordionCard(
        sectionKey: 'buyer',
        icon: LucideIcons.building2,
        tint: _blue,
        title: 'Buyer Details',
        summary: requirement.buyerCompanyName,
        child: Column(
          children: [
            _infoRow('Company', requirement.buyerCompanyName),
            _infoRow('Verification', requirement.isBuyerVerified ? 'Verified' : 'Not verified'),
            if (requirement.buyerTrustScore > 0) _infoRow('Trust Score', '${requirement.buyerTrustScore}%'),
          ],
        ),
      ),

      // 6. Documents (no document source exists on the broker app)
      const DetailAccordionCard(
        sectionKey: 'documents',
        icon: LucideIcons.fileText,
        tint: _slate,
        title: 'Documents',
        summary: 'Not available yet',
        child: Text(
          'Requirement documents are not available in the broker app yet.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
        ),
      ),

      // 7. Audit Details
      DetailAccordionCard(
        sectionKey: 'audit',
        icon: LucideIcons.shieldCheck,
        tint: _pink,
        title: 'Audit Details',
        summary: 'Created: ${DateFormat('dd MMM yyyy').format(requirement.createdAt)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _infoRow('Created', dateFormat.format(requirement.createdAt)),
            _infoRow('Assigned Broker', assignment),
            if (requirement.rawStatus != null) _infoRow('Recorded Status', requirement.rawStatus!),
            if (requirement.notes != null && requirement.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
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
    ];
  }
}
