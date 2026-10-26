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
  String _selectedStatus = 'ALL';
  bool _isLoading = true;
  String? _errorMessage;
  List<BuyerRequirement> _requirements = [];

  final List<String> _statusFilters = [
    'ALL',
    'Open',
    'In Negotiation',
    'Allocated',
    'Fulfilled',
  ];

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
    super.dispose();
  }

  Future<void> _loadRequirements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repo.getRequirements(statusFilter: _selectedStatus);
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
        onPressed: () async {
          await context.push('/requirements/new');
          if (mounted) {
            _loadRequirements();
          }
        },
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: const Text(
          'Post Requirement',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceLight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statusFilters.map((s) {
                    final isSelected = _selectedStatus == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s == 'ALL' ? 'All Requirements' : s),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedStatus = s;
                            });
                            _loadRequirements();
                          }
                        },
                        selectedColor: AppColors.primaryContainer,
                        backgroundColor: AppColors.surfaceLight,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.primaryDark : AppColors.textSecondaryLight,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.borderLight,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(),

            // Requirements List View
            Expanded(
              child: _buildRequirementsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementsList() {
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
        description: _selectedStatus == 'ALL'
            ? 'You have not posted any commodity procurement requirements yet. Post your first requirement to receive broker quotes.'
            : 'No requirements currently matching "$_selectedStatus" status.',
        icon: LucideIcons.clipboardList,
        actionLabel: 'Post Your Requirement',
        onAction: () async {
          await context.push('/requirements/new');
          if (mounted) {
            _loadRequirements();
          }
        },
      );
    }

    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return RefreshIndicator(
      onRefresh: _loadRequirements,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _requirements.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final req = _requirements[index];
          return InkWell(
            onTap: () => _showRequirementDetails(req),
            borderRadius: BorderRadius.circular(12),
            child: AppCard(
              padding: const EdgeInsets.all(16),
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              req.gradeName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: req.status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric('Target Quantity', '${req.quantity} ${req.unit}'),
                      _buildMetric(
                        'Target Price',
                        '${currencyFormat.format(req.targetPrice)}/${req.unit}',
                      ),
                      _buildMetric(
                        'Delivery Due',
                        DateFormat('dd MMM yyyy').format(req.targetDate),
                      ),
                    ],
                  ),
                  if (req.deliveryTerms != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.truck,
                          size: 14,
                          color: AppColors.textMutedLight,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            req.deliveryTerms!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (req.brokerName != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.briefcase,
                          size: 14,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Assigned Desk: ${req.brokerName!}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMutedLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}
