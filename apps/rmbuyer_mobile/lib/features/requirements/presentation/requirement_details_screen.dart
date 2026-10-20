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
import '../domain/requirement_timeline_event.dart';

/// Screen presenting authoritative requirement details, commercial terms,
/// verified lifecycle status tracking, and chronological activity timeline.
class RequirementDetailsScreen extends StatefulWidget {
  final String requirementId;
  final BuyerRequirement? initialRequirement;
  final RequirementsRepository? repository;

  const RequirementDetailsScreen({
    super.key,
    required this.requirementId,
    this.initialRequirement,
    this.repository,
  });

  @override
  State<RequirementDetailsScreen> createState() => _RequirementDetailsScreenState();
}

class _RequirementDetailsScreenState extends State<RequirementDetailsScreen> {
  late final RequirementsRepository _repo;
  BuyerRequirement? _requirement;
  List<RequirementTimelineEvent> _timelineEvents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RequirementsRepository();
    _requirement = widget.initialRequirement;
    _loadRequirement();
  }

  Future<void> _loadRequirement() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final req = await _repo.getRequirementById(widget.requirementId) ?? widget.initialRequirement;
      if (!mounted) return;

      if (req == null) {
        setState(() {
          _requirement = null;
          _isLoading = false;
        });
        return;
      }

      final events = await _repo.getTimelineEvents(req.id);
      final finalEvents = events.isNotEmpty
          ? events
          : RequirementTimelineEvent.fromRequirement(req);

      if (!mounted) return;

      setState(() {
        _requirement = req;
        _timelineEvents = finalEvents;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load requirement details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCancelRequirement() async {
    final req = _requirement;
    if (req == null) return;

    final reasonController = TextEditingController();

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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel mandate ${req.id} for ${req.quantity} ${req.unit} of ${req.commodityName}?',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: reasonController,
              label: 'Reason for Cancellation *',
              hint: 'e.g. Procurement target satisfied, Changed delivery mandi',
              maxLines: 2,
            ),
          ],
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
                  const SnackBar(content: Text('Please enter a valid cancellation reason (min 3 chars)')),
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
        _loadRequirement();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cancellation error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _requirement != null ? 'Mandate: ${_requirement!.id}' : 'Requirement Details',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCw),
            tooltip: 'Refresh',
            onPressed: _loadRequirement,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingIndicator(
        message: 'Loading verified requirement details and timeline...',
      );
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        onRetry: _loadRequirement,
      );
    }

    final req = _requirement;
    if (req == null) {
      return AppEmptyState(
        title: 'Requirement Not Found',
        description:
            'The requested requirement does not exist or you do not have authorization to view it.',
        icon: LucideIcons.fileX,
        actionLabel: 'Return to Requirements',
        onAction: () => context.pop(),
      );
    }

    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return RefreshIndicator(
      onRefresh: _loadRequirement,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header Card
            _buildStatusHeaderCard(req),
            const SizedBox(height: 16),

            // Commercial Metrics Card
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Commodity & Commercial Terms',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricItem('Commodity', req.commodityName),
                      _buildMetricItem('Quality Grade', req.gradeName),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricItem('Target Quantity', '${req.quantity} ${req.unit}'),
                      _buildMetricItem(
                        'Target Price',
                        '${currencyFormat.format(req.targetPrice)}/${req.unit}',
                      ),
                      _buildMetricItem(
                        'Est. Mandate Value',
                        currencyFormat.format(req.totalEstimatedValue),
                      ),
                    ],
                  ),
                  if (req.fulfilledQuantity > 0) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricItem(
                          'Fulfilled Quantity',
                          '${req.fulfilledQuantity} ${req.unit} (${((req.fulfilledQuantity / req.quantity) * 100).toStringAsFixed(0)}%)',
                        ),
                        _buildMetricItem(
                          'Remaining Balance',
                          '${req.quantity - req.fulfilledQuantity} ${req.unit}',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Logistics & Delivery Card
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Logistics & Commercial Preferences',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (req.deliveryTerms != null) ...[
                    _buildIconDetailRow(
                      icon: LucideIcons.truck,
                      label: 'Delivery Location / Terms',
                      value: req.deliveryTerms!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildIconDetailRow(
                    icon: LucideIcons.calendar,
                    label: 'Required Delivery By Date',
                    value: DateFormat('dd MMMM yyyy').format(req.targetDate),
                  ),
                  if (req.paymentTerms != null) ...[
                    const SizedBox(height: 12),
                    _buildIconDetailRow(
                      icon: LucideIcons.creditCard,
                      label: 'Preferred Payment Terms',
                      value: '${req.paymentTerms!} (Non-binding Buyer Preference)',
                    ),
                  ],
                  if (req.packagingType != null) ...[
                    const SizedBox(height: 12),
                    _buildIconDetailRow(
                      icon: LucideIcons.package,
                      label: 'Packaging Type',
                      value: req.packagingType!,
                    ),
                  ],
                  if (req.notes != null) ...[
                    const SizedBox(height: 12),
                    _buildIconDetailRow(
                      icon: LucideIcons.fileText,
                      label: 'Mandate Notes',
                      value: req.notes!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Broker Routing & Counterparty Shield Card
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Broker Desk & Counterparty Security',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildIconDetailRow(
                    icon: LucideIcons.briefcase,
                    label: 'Assigned Mandi Broker Desk',
                    value: req.brokerName ?? 'Global Mandi Broadcast (Open to all verified brokers)',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Counterparty Shield Active: Direct seller records and trade offers remain strictly broker-mediated. Sourcing, quality verification, and counterparty contracts are managed through your broker desk.',
                            style: TextStyle(fontSize: 11, color: AppColors.primaryDark, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Broker Offers & Negotiation Card (Sprint RB-BUYER-05)
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(LucideIcons.badgePercent, size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Broker Commercial Offers',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Negotiation Desk',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Review commercial proposals, submit counter-offer rates, and negotiate through your assigned broker desk.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(LucideIcons.arrowRight, size: 16),
                      label: const Text('View Broker Offers & Negotiate'),
                      onPressed: () {
                        context.push('/offers?requirementId=${req.id}');
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Activity Timeline Section (Phase E)
            _buildTimelineSection(),
            const SizedBox(height: 24),

            // Actions Section (Phase F)
            _buildActionsSection(req),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeaderCard(BuyerRequirement req) {
    String statusExplanation;
    final statusLower = req.status.toLowerCase();

    if (statusLower == 'open') {
      statusExplanation =
          'Mandate is active on the verified mandi broker floor. Awaiting broker counterparty sourcing and price matching.';
    } else if (statusLower == 'in negotiation') {
      statusExplanation =
          'Assigned broker desk is currently negotiating lot sizes, moisture specs, and pricing with vetted sellers.';
    } else if (statusLower == 'allocated') {
      statusExplanation =
          'Broker has allocated specific counterparty lots against your mandate. Deal contracts in preparation.';
    } else if (statusLower == 'fulfilled') {
      statusExplanation =
          'Procurement mandate has been completely converted into confirmed deals. Ready for trade execution.';
    } else if (statusLower == 'cancelled') {
      statusExplanation =
          'This procurement mandate was cancelled and is no longer broadcast to brokers.';
    } else {
      statusExplanation = 'Mandate is in authoritative state "${req.status}".';
    }

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status: ${req.status}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              StatusBadge(status: req.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusExplanation,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.history, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Activity Timeline & Status History',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Authoritative milestones recorded in the shared database.',
            style: TextStyle(fontSize: 11, color: AppColors.textMutedLight),
          ),
          const SizedBox(height: 16),

          if (_timelineEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No recorded milestone events available for this mandate.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _timelineEvents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final event = _timelineEvents[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: event.isCurrent
                                ? AppColors.secondary
                                : (event.isCompleted
                                    ? AppColors.primary
                                    : AppColors.borderLight),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            event.isCompleted ? LucideIcons.check : LucideIcons.clock,
                            size: 12,
                            color: event.isCompleted ? Colors.white : AppColors.textMutedLight,
                          ),
                        ),
                        if (index < _timelineEvents.length - 1)
                          Container(
                            width: 2,
                            height: 38,
                            color: AppColors.borderLight,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                event.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: event.isCurrent ? FontWeight.w800 : FontWeight.w600,
                                  color: event.isCurrent
                                      ? AppColors.textPrimaryLight
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                              Text(
                                DateFormat('dd MMM, hh:mm a').format(event.timestamp),
                                style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            event.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 8),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, size: 14, color: AppColors.textMutedLight),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Audit Notice: All timestamps reflect authoritative backend database entries. Intermediate counterparty negotiations are held in confidence by your broker desk.',
                  style: TextStyle(fontSize: 10, color: AppColors.textMutedLight, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(BuyerRequirement req) {
    if (req.canCancel) {
      return AppButton(
        label: 'Cancel Procurement Mandate',
        onPressed: _handleCancelRequirement,
        variant: AppButtonVariant.outline,
        icon: LucideIcons.xCircle,
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Center(
        child: Text(
          'Requirement in "${req.status}" state is locked in active trade operations and cannot be cancelled directly.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
        ),
      ],
    );
  }

  Widget _buildIconDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMutedLight),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
