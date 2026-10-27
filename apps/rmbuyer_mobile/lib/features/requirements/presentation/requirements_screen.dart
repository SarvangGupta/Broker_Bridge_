import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/requirements_repository.dart';
import '../domain/requirement_list_filter.dart';
import '../domain/requirement_model.dart';
import '../../../l10n/app_localizations.dart';

/// Screen listing buyer's commodity procurement requirements with status filters,
/// detailed mandate view, and authorized cancellation workflow.
class RequirementsScreen extends StatefulWidget {
  final RequirementsRepository? repository;

  const RequirementsScreen({super.key, this.repository});

  @override
  State<RequirementsScreen> createState() => _RequirementsScreenState();
}

class _RequirementsScreenState extends State<RequirementsScreen> {
  late final RequirementsRepository _repo;
  bool _isLoading = true;
  String? _errorMessage;

  /// Every requirement the repository returned; counts and filters derive
  /// from this list client-side (the repository caps live rows at 50).
  List<BuyerRequirement> _requirements = [];

  final TextEditingController _searchController = TextEditingController();
  RequirementListQuery _query = const RequirementListQuery();
  final Set<DeliveryGroup> _collapsedGroups = {};

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RequirementsRepository();
    RequirementsRepository.requirementsUpdatedNotifier.addListener(_loadRequirements);
    _loadRequirements();
  }

  @override
  void dispose() {
    RequirementsRepository.requirementsUpdatedNotifier.removeListener(_loadRequirements);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequirements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repo.getRequirements(statusFilter: 'ALL');
      if (!mounted) return;
      setState(() {
        _requirements = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load requirements. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCancelRequirement(BuyerRequirement req) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.alertCircle, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text(
              'Cancel Requirement',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel your requirement for ${req.quantity} ${req.unit} of ${req.commodityName}?',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: reasonController,
                label: 'Reason for Cancellation *',
                hint: 'e.g. Procurement target satisfied, Changed mandi',
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Active'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().length >= 3) {
                Navigator.of(ctx).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a valid cancellation reason (min 3 chars)')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.cancelRequirement(req.id, reason: reasonController.text.trim());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Requirement ${req.id} cancelled successfully')),
        );
        _loadRequirements();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cancellation error: $e')),
        );
      }
    }
  }

  void _showRequirementDetails(BuyerRequirement req) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              16 + MediaQuery.paddingOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header: commodity, grade and status
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.package,
                        size: 24,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.commodityName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            req.gradeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(status: req.status),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Requirement ID with copy
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Requirement ID: ${req.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMutedLight,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('copy-requirement-id'),
                      icon: const Icon(LucideIcons.copy, size: 16),
                      color: AppColors.textSecondaryLight,
                      tooltip: 'Copy Requirement ID',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: req.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Requirement ID copied')),
                        );
                      },
                    ),
                  ],
                ),
                if (req.createdAt != null)
                  Text(
                    'Created: ${DateFormat('dd MMM yyyy').format(req.createdAt!)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight),
                  ),
                const SizedBox(height: 10),

                // Key metrics card
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: _cardDecoration(),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMetricCell(
                          LucideIcons.package,
                          'Target Quantity',
                          '${req.quantity} ${req.unit}',
                        ),
                        const VerticalDivider(width: 1),
                        _buildMetricCell(
                          LucideIcons.indianRupee,
                          'Target Price',
                          '${currencyFormat.format(req.targetPrice)}/${req.unit}',
                        ),
                        const VerticalDivider(width: 1),
                        _buildMetricCell(
                          LucideIcons.chartColumn,
                          'Est. Mandate Value',
                          currencyFormat.format(req.totalEstimatedValue),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Delivery due (and payment terms when present)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: _cardDecoration(),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.calendarDays, size: 20, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCol(
                          'Target Delivery Due',
                          DateFormat('dd MMMM yyyy').format(req.targetDate),
                        ),
                      ),
                      if (req.paymentTerms != null) ...[
                        const SizedBox(width: 8),
                        Expanded(child: _buildMetricCol('Payment Terms', req.paymentTerms!)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Delivery location
                if (req.deliveryTerms != null)
                  _buildInfoRow(
                    LucideIcons.mapPin,
                    'Delivery Location / Mandi Terms',
                    req.deliveryTerms!,
                  ),
                if (req.deliveryTerms != null) const Divider(height: 1),

                // Assigned broker desk
                _buildInfoRow(
                  LucideIcons.users,
                  'Assigned Mandi Broker Desk',
                  req.brokerName ?? 'Global Broadcast (All Verified Brokers)',
                ),
                const SizedBox(height: 8),

                // Counterparty Shield Notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successBackground.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.shieldCheck, size: 20, color: AppColors.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Seller identity is protected. ',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text:
                                    'Negotiations and quality inspections are broker-mediated through your assigned broker desk.',
                              ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
                AppButton(
                  label: 'View Timeline & Full Details',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push('/requirements/${req.id}', extra: req);
                  },
                  variant: AppButtonVariant.primary,
                  icon: LucideIcons.history,
                ),
                const SizedBox(height: 10),
                if (req.canCancel)
                  AppButton(
                    label: 'Cancel Requirement',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _handleCancelRequirement(req);
                    },
                    variant: AppButtonVariant.outline,
                    icon: LucideIcons.xCircle,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: _cardDecoration(),
                    child: Center(
                      child: Text(
                        'Requirement in "${req.status}" state is locked in broker negotiations and cannot be cancelled directly.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.borderLight),
    );
  }

  Widget _buildMetricCell(IconData icon, String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(child: _buildMetricCol(label, value)),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(context.tr(Tr.titleRequirements)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCw),
            tooltip: 'Refresh',
            onPressed: _loadRequirements,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPostRequirement,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: const Text(
          'Post Requirement',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Future<void> _openPostRequirement() async {
    await context.push('/requirements/new');
    if (mounted) _loadRequirements();
  }

  void _setQuery(RequirementListQuery q) => setState(() => _query = q);

  RequirementListQuery _copyQuery({
    RequirementStatusBucket? status,
    bool clearStatus = false,
    String? search,
    RequirementSort? sort,
    DeliveryDateFilter? dateFilter,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final q = _query;
    final nextDate = dateFilter ?? q.dateFilter;
    final keepRange = nextDate == DeliveryDateFilter.custom;
    return RequirementListQuery(
      status: clearStatus ? null : (status ?? q.status),
      search: search ?? q.search,
      sort: sort ?? q.sort,
      dateFilter: nextDate,
      customStart: keepRange ? (customStart ?? q.customStart) : null,
      customEnd: keepRange ? (customEnd ?? q.customEnd) : null,
    );
  }

  void _selectStatus(RequirementStatusBucket? bucket) {
    _setQuery(bucket == null ? _copyQuery(clearStatus: true) : _copyQuery(status: bucket));
  }

  void _resetFilters() {
    _searchController.clear();
    _setQuery(const RequirementListQuery());
  }

  Future<void> _onDateFilterChanged(DeliveryDateFilter? value) async {
    if (value == null) return;
    if (value != DeliveryDateFilter.custom) {
      _setQuery(_copyQuery(dateFilter: value));
      return;
    }
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
      initialDateRange: _query.customStart != null && _query.customEnd != null
          ? DateTimeRange(start: _query.customStart!, end: _query.customEnd!)
          : null,
    );
    if (range == null || !mounted) return;
    _setQuery(_copyQuery(
      dateFilter: DeliveryDateFilter.custom,
      customStart: range.start,
      customEnd: range.end,
    ));
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingIndicator(
        message: 'Loading your procurement requirements...',
      );
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        onRetry: _loadRequirements,
      );
    }

    if (_requirements.isEmpty) {
      return AppEmptyState(
        title: 'No Requirements Found',
        description:
            'You have not posted any commodity procurement requirements yet. Post your first requirement to receive broker quotes.',
        icon: LucideIcons.clipboardList,
        actionLabel: 'Post Your Requirement',
        onAction: _openPostRequirement,
      );
    }

    final today = DateTime.now();
    final filtered = applyRequirementQuery(_requirements, _query, today);
    final groups = groupByDelivery(filtered, today);

    return RefreshIndicator(
      onRefresh: _loadRequirements,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildControls()),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                child: AppEmptyState(
                  title: 'No matching requirements',
                  description: 'Try a different search or clear the filters.',
                  icon: LucideIcons.searchX,
                  actionLabel: 'Clear Filters',
                  onAction: _resetFilters,
                ),
              ),
            )
          else ...[
            for (final group in DeliveryGroup.values)
              if (groups[group]!.isNotEmpty) ..._buildGroup(group, groups[group]!, today),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ],
      ),
    );
  }

  Widget _buildControls() {
    final counts = bucketCounts(_requirements);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary cards
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _summaryCard(null, 'All', _requirements.length, AppColors.primary),
                for (final b in RequirementStatusBucket.values)
                  _summaryCard(b, b.label, counts[b]!, _bucketColor(b)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search
          TextField(
            controller: _searchController,
            onChanged: (v) => _setQuery(_copyQuery(search: v)),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search commodity or requirement ID',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        _setQuery(_copyQuery(search: ''));
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Status chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusChip(null, 'All'),
                for (final b in RequirementStatusBucket.values) _statusChip(b, b.label),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Sort + delivery date
          Row(
            children: [
              Expanded(
                child: _dropdown<RequirementSort>(
                  key: const Key('req-sort'),
                  icon: LucideIcons.calendarDays,
                  value: _query.sort,
                  items: const {
                    RequirementSort.earliestDelivery: 'Earliest Delivery First',
                    RequirementSort.latestDelivery: 'Latest Delivery First',
                    RequirementSort.newestPosted: 'Newest Posted First',
                  },
                  onChanged: (v) {
                    if (v != null) _setQuery(_copyQuery(sort: v));
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdown<DeliveryDateFilter>(
                  key: const Key('req-date-filter'),
                  icon: LucideIcons.arrowUpDown,
                  value: _query.dateFilter,
                  items: {
                    DeliveryDateFilter.all: 'All Dates',
                    DeliveryDateFilter.overdue: 'Overdue',
                    DeliveryDateFilter.due7: 'Due in 7 Days',
                    DeliveryDateFilter.due30: 'Due in 30 Days',
                    DeliveryDateFilter.custom: _query.customStart != null && _query.customEnd != null
                        ? '${DateFormat('dd MMM').format(_query.customStart!)} – ${DateFormat('dd MMM').format(_query.customEnd!)}'
                        : 'Custom Range',
                  },
                  onChanged: _onDateFilterChanged,
                ),
              ),
            ],
          ),
          if (!_query.isDefault)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('req-clear-filters'),
                onPressed: _resetFilters,
                icon: const Icon(LucideIcons.filterX, size: 14),
                label: const Text('Clear filters', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  Color _bucketColor(RequirementStatusBucket b) {
    switch (b) {
      case RequirementStatusBucket.open:
        return AppColors.info;
      case RequirementStatusBucket.inNegotiation:
        return AppColors.warning;
      case RequirementStatusBucket.proposalReceived:
        return const Color(0xFF7C3AED);
      case RequirementStatusBucket.confirmed:
        return AppColors.success;
      case RequirementStatusBucket.completed:
        return AppColors.textSecondaryLight;
    }
  }

  Widget _summaryCard(RequirementStatusBucket? bucket, String label, int count, Color color) {
    final selected = _query.status == bucket;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: color.withValues(alpha: selected ? 0.16 : 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: InkWell(
          key: Key('req-summary-${bucket?.name ?? 'all'}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectStatus(bucket),
          child: Container(
            constraints: const BoxConstraints(minWidth: 72),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$count',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(RequirementStatusBucket? bucket, String label) {
    final selected = _query.status == bucket;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => _selectStatus(bucket),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceLight,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? Colors.white : AppColors.textSecondaryLight,
        ),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.borderLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _dropdown<T>({
    required Key key,
    required IconData icon,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: key,
          value: value,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, size: 16),
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimaryLight),
          selectedItemBuilder: (_) => [
            for (final label in items.values)
              Row(
                children: [
                  Icon(icon, size: 15, color: AppColors.textSecondaryLight),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
          ],
          items: [
            for (final e in items.entries)
              DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<Widget> _buildGroup(DeliveryGroup group, List<BuyerRequirement> items, DateTime today) {
    final (label, icon, color) = switch (group) {
      DeliveryGroup.overdue => ('Overdue', LucideIcons.alertCircle, AppColors.error),
      DeliveryGroup.dueSoon => ('Due in 7 Days', LucideIcons.clock, AppColors.warning),
      DeliveryGroup.upcoming => ('Upcoming', LucideIcons.calendarDays, AppColors.success),
      DeliveryGroup.dateNotSet => ('Date Not Set', LucideIcons.calendarX, AppColors.textSecondaryLight),
    };
    final collapsed = _collapsedGroups.contains(group);

    return [
      SliverToBoxAdapter(
        child: Material(
          color: color.withValues(alpha: 0.08),
          child: InkWell(
            key: Key('req-group-${group.name}'),
            onTap: () => setState(() {
              collapsed ? _collapsedGroups.remove(group) : _collapsedGroups.add(group);
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$label (${items.length})',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                    ),
                  ),
                  Icon(
                    collapsed ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                    size: 18,
                    color: color,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      if (!collapsed)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _buildRequirementCard(items[i], group, today),
          ),
        ),
    ];
  }

  Widget _buildRequirementCard(BuyerRequirement req, DeliveryGroup group, DateTime today) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final days = req.hasTargetDate ? daysUntilDelivery(req, today) : null;

    String? dueLabel;
    Color dueColor = AppColors.textPrimaryLight;
    if (group == DeliveryGroup.overdue && days != null) {
      dueLabel = 'Overdue by ${-days} day${days == -1 ? '' : 's'}';
      dueColor = AppColors.error;
    } else if (group == DeliveryGroup.dueSoon && days != null) {
      dueLabel = days == 0 ? 'Due today' : 'Due in $days day${days == 1 ? '' : 's'}';
      dueColor = AppColors.warning;
    } else if (group == DeliveryGroup.upcoming) {
      dueColor = AppColors.success;
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      onTap: () => _showRequirementDetails(req),
      child: Row(
        children: [
          Expanded(
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
                            req.commodityName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            req.id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (dueLabel != null) _dueBadge(dueLabel, dueColor),
                          StatusBadge(status: req.status),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildMetric('Target Quantity', '${req.quantity} ${req.unit}')),
                      if (req.targetPrice > 0) ...[
                        const VerticalDivider(width: 12),
                        Expanded(
                          child: _buildMetric(
                            'Target Price',
                            '${currencyFormat.format(req.targetPrice)}/${req.unit}',
                          ),
                        ),
                      ],
                      const VerticalDivider(width: 12),
                      Expanded(
                        child: _buildMetric(
                          'Delivery Due',
                          req.hasTargetDate ? DateFormat('dd MMM yyyy').format(req.targetDate) : 'Not set',
                          valueColor: dueColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (req.deliveryTerms != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin, size: 13, color: AppColors.textMutedLight),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          req.deliveryTerms!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ],
                  ),
                ],
                if (req.brokerName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.briefcase, size: 13, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Assigned Desk: ${req.brokerName!}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMutedLight),
        ],
      ),
    );
  }

  Widget _dueBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildMetric(String label, String value, {Color valueColor = AppColors.textPrimaryLight}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMutedLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
