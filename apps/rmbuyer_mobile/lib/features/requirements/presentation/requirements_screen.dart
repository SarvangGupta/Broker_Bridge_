import 'package:flutter/material.dart';
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
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.commodityName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          req.gradeName,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: req.status),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Mandate Identifiers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Requirement ID: ${req.id}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMutedLight),
                  ),
                  if (req.createdAt != null)
                    Text(
                      'Created: ${DateFormat('dd MMM yyyy').format(req.createdAt!)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMutedLight),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Metrics Grid
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCol('Target Quantity', '${req.quantity} ${req.unit}'),
                        _buildMetricCol('Target Price', '${currencyFormat.format(req.targetPrice)}/${req.unit}'),
                        _buildMetricCol(
                          'Est. Mandate Value',
                          currencyFormat.format(req.totalEstimatedValue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCol(
                          'Target Delivery Due',
                          DateFormat('dd MMMM yyyy').format(req.targetDate),
                        ),
                        if (req.paymentTerms != null)
                          _buildMetricCol('Payment Terms', req.paymentTerms!),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Delivery Mandi Location
              if (req.deliveryTerms != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.truck, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivery Location / Mandi Terms',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMutedLight),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            req.deliveryTerms!,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Assigned Broker Desk
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.briefcase, size: 16, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assigned Mandi Broker Desk',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMutedLight),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          req.brokerName ?? 'Global Broadcast (All Verified Brokers)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Counterparty Shield Notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Direct seller identities are protected and broker-mediated. All counterparty negotiations and quality inspections are executed via your assigned broker desk.',
                        style: TextStyle(fontSize: 11, color: AppColors.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

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
              const SizedBox(height: 12),
              if (req.canCancel)
                AppButton(
                  label: 'Cancel Procurement Mandate',
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
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Center(
                    child: Text(
                      'Requirement in "${req.status}" state is locked in broker negotiations and cannot be cancelled directly.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
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
        title: const Text('Procurement Requirements'),
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
