import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/buyer_deals_repository.dart';
import '../domain/final_deal_review_model.dart';

/// Screen presenting the final negotiated commercial proposal for explicit buyer confirmation.
/// Enforces strict Counterparty Shield (zero seller data) and optimistic concurrency.
class FinalDealReviewScreen extends StatefulWidget {
  final String dealId;
  final BuyerDealsRepository? repository;

  const FinalDealReviewScreen({
    super.key,
    required this.dealId,
    this.repository,
  });

  @override
  State<FinalDealReviewScreen> createState() => _FinalDealReviewScreenState();
}

class _FinalDealReviewScreenState extends State<FinalDealReviewScreen> {
  late final BuyerDealsRepository _repo;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  FinalDealReviewData? _dealData;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? BuyerDealsRepository();
    _loadDealReview();
  }

  Future<void> _loadDealReview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _repo.getFinalDealReview(widget.dealId);
      if (!mounted) return;
      setState(() {
        _dealData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleConfirmDeal() async {
    final deal = _dealData;
    if (deal == null) return;

    bool termsAgreed = false;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final currencyFormat = NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹',
              decimalDigits: 0,
            );

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const Row(
                      children: [
                        Icon(LucideIcons.fileCheck,
                            color: AppColors.primary, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Confirm Final Deal Terms',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${deal.currentTerms.commodityName} (${deal.currentTerms.gradeName})',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Agreed Quantity: ${deal.currentTerms.quantity} ${deal.currentTerms.unitSymbol} @ ${currencyFormat.format(deal.currentTerms.basePricePerUnit)}/${deal.currentTerms.unitSymbol}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          Text(
                            'Net Landed: ${currencyFormat.format(deal.currentTerms.netLandedPricePerUnit)}/${deal.currentTerms.unitSymbol} | Total: ${currencyFormat.format(deal.currentTerms.totalEstimatedValue)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'By clicking Confirm Deal, you formally approve this commercial snapshot (v${deal.versionNumber}). This unlocks broker trade execution. Final trade contracts will be issued shortly.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: termsAgreed,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setModalState(() {
                              termsAgreed = val ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'I have verified and accept all commercial terms, quality parameters, and delivery conditions.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Cancel',
                            variant: AppButtonVariant.outline,
                            onPressed: () => Navigator.of(modalCtx).pop(false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            key: const Key('modal_confirm_deal_btn'),
                            label: 'Confirm Deal',
                            variant: AppButtonVariant.primary,
                            onPressed: termsAgreed ? () => Navigator.of(modalCtx).pop(true) : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final input = ConfirmDealInput(
        dealId: deal.dealId,
        expectedVersion: deal.versionNumber,
        buyerConfirmed: true,
      );

      final updated = await _repo.confirmFinalDeal(input);
      if (!mounted) return;

      setState(() {
        _dealData = updated;
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Final Deal Snapshot confirmed successfully. Broker contract issuance unlocked.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      if (e is StaleVersionException) {
        _showStaleVersionDialog(e.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleRequestAmendment() async {
    final deal = _dealData;
    if (deal == null) return;

    final reasonController = TextEditingController();
    String? validationError;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(LucideIcons.filePenLine,
                      color: AppColors.secondary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Request Amendment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Provide details on what terms need modification (e.g. rate, quantity, delivery window, or payment terms). Your request will be sent to the Broker desk.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Amendment Reason / Required Changes',
                    hint: 'Describe required modifications (min 5 characters)...',
                    controller: reasonController,
                    maxLines: 3,
                    errorText: validationError,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final text = reasonController.text.trim();
                    if (text.length < 5) {
                      setDialogState(() {
                        validationError = 'Please enter at least 5 characters.';
                      });
                      return;
                    }
                    Navigator.of(dialogCtx).pop(true);
                  },
                  child: const Text('Submit Request'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final input = RequestAmendmentInput(
        dealId: deal.dealId,
        expectedVersion: deal.versionNumber,
        reason: reasonController.text.trim(),
      );

      final updated = await _repo.requestDealAmendment(input);
      if (!mounted) return;

      setState(() {
        _dealData = updated;
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Amendment request submitted to the Broker desk. New proposal iteration required.',
          ),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      if (e is StaleVersionException) {
        _showStaleVersionDialog(e.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showStaleVersionDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 20),
            SizedBox(width: 8),
            Text('Version Update Detected',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.of(ctx).pop();
              _loadDealReview();
            },
            child: const Text('Refresh Latest Terms'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deal = _dealData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Deal Review'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCw),
            tooltip: 'Refresh',
            onPressed: _loadDealReview,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const AppLoadingIndicator(
                message: 'Loading authoritative deal snapshot & terms...',
              )
            : _errorMessage != null
                ? AppErrorState(
                    message: _errorMessage!,
                    onRetry: _loadDealReview,
                  )
                : deal == null
                    ? const Center(child: Text('Deal snapshot not found.'))
                    : Column(
                        children: [
                          // Counterparty Shield Banner
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            color:
                                AppColors.primaryContainer.withValues(alpha: 0.6),
                            child: const Row(
                              children: [
                                Icon(LucideIcons.shieldCheck,
                                    size: 15, color: AppColors.primary),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Counterparty Shield: Trade terms mediated exclusively by licensed Broker Desk. Direct counterparty details shielded.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeaderCard(deal),
                                  const SizedBox(height: 12),
                                  if (deal.hasPreviousVersion &&
                                      deal.previousTerms != null) ...[
                                    _buildVisualDiffCard(deal),
                                    const SizedBox(height: 12),
                                  ],
                                  _buildCommercialOverviewCard(deal),
                                  const SizedBox(height: 12),
                                  _buildChargesLedgerCard(deal),
                                  const SizedBox(height: 12),
                                  _buildDeliveryAndLogisticsCard(deal),
                                  const SizedBox(height: 12),
                                  _buildQualitySpecsCard(deal),
                                  const SizedBox(height: 12),
                                  _buildBrokerDeskCard(deal),
                                  const SizedBox(height: 12),
                                  _buildTradeMilestonesCard(deal),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),

                          // Bottom Action Bar
                          _buildBottomActionBar(deal),
                        ],
                      ),
      ),
    );
  }

  Widget _buildHeaderCard(FinalDealReviewData deal) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deal Ref: ${deal.dealId}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mandate Ref: ${deal.requirementDisplayId}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: deal.status.label),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.history,
                    size: 13, color: AppColors.primaryDark),
                const SizedBox(width: 6),
                Text(
                  'Deal Snapshot v${deal.versionNumber} • Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(deal.snapshotTimestamp)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualDiffCard(FinalDealReviewData deal) {
    final curr = deal.currentTerms;
    final prev = deal.previousTerms!;
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final diffs = <Widget>[];

    // Rate diff
    if (curr.basePricePerUnit != prev.basePricePerUnit) {
      diffs.add(_buildDiffItem(
        'Base Commodity Rate',
        '${currencyFormat.format(prev.basePricePerUnit)}/${prev.unitSymbol}',
        '${currencyFormat.format(curr.basePricePerUnit)}/${curr.unitSymbol}',
      ));
    }

    // Quantity diff
    if (curr.quantity != prev.quantity) {
      diffs.add(_buildDiffItem(
        'Agreed Quantity',
        '${prev.quantity} ${prev.unitSymbol}',
        '${curr.quantity} ${curr.unitSymbol}',
      ));
    }

    // Payment terms diff
    if (curr.paymentTerms != prev.paymentTerms) {
      diffs.add(_buildDiffItem(
        'Payment Terms',
        prev.paymentTerms,
        curr.paymentTerms,
      ));
    }

    // Packaging diff
    if (curr.packagingType != prev.packagingType) {
      diffs.add(_buildDiffItem(
        'Packaging Type',
        prev.packagingType,
        curr.packagingType,
      ));
    }

    // Freight terms diff
    if (curr.freightTerms != prev.freightTerms) {
      diffs.add(_buildDiffItem(
        'Freight Terms',
        prev.freightTerms,
        curr.freightTerms,
      ));
    }

    if (diffs.isEmpty) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.gitCompare,
                  size: 16, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                'Changes in Version ${deal.versionNumber} (vs v${deal.previousVersionNumber})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...diffs,
        ],
      ),
    );
  }

  Widget _buildDiffItem(String label, String oldValue, String newValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    oldValue,
                    style: const TextStyle(
                      fontSize: 11,
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.textMutedLight,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(LucideIcons.arrowRight,
                      size: 12, color: AppColors.secondary),
                ),
                Flexible(
                  child: Text(
                    newValue,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
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

  Widget _buildCommercialOverviewCard(FinalDealReviewData deal) {
    final terms = deal.currentTerms;
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.receipt,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Agreed Commercial Terms (${terms.commodityName})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric('Quantity', '${terms.quantity} ${terms.unitSymbol}'),
              _buildMetric('Base Rate',
                  '${currencyFormat.format(terms.basePricePerUnit)}/${terms.unitSymbol}'),
              _buildMetric('Net Landed',
                  '${currencyFormat.format(terms.netLandedPricePerUnit)}/${terms.unitSymbol}'),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Estimated Value',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              Text(
                currencyFormat.format(terms.totalEstimatedValue),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Estimated Total: Based on agreed contract rate. Final payable is subject to certified weighbridge slip weight at destination.',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: AppColors.textMutedLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargesLedgerCard(FinalDealReviewData deal) {
    final terms = deal.currentTerms;
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.listCheck, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Transparent Charges Ledger',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...terms.applicableCharges.map((charge) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          charge.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        if (charge.description.isNotEmpty)
                          Text(
                            charge.description,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${charge.rate}/${terms.unitSymbol}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        currencyFormat.format(charge.amount),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Facilitation & Mandi Charges',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              Text(
                '₹${terms.totalChargesPerUnit}/${terms.unitSymbol}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAndLogisticsCard(FinalDealReviewData deal) {
    final terms = deal.currentTerms;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.truck, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Delivery & Logistics Terms',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Delivery Location', terms.deliveryLocation),
          if (terms.deliveryWindowStart != null && terms.deliveryWindowEnd != null)
            _buildInfoRow(
              'Delivery Window',
              '${DateFormat('dd MMM yyyy').format(terms.deliveryWindowStart!)} – ${DateFormat('dd MMM yyyy').format(terms.deliveryWindowEnd!)}',
            ),
          _buildInfoRow('Packaging Type', terms.packagingType),
          _buildInfoRow('Freight Terms', terms.freightTerms),
          _buildInfoRow('Payment Terms', terms.paymentTerms),
          _buildInfoRow('Inspection / Lab QA', terms.inspectionRequirements),
          if (terms.specialConditions != null)
            _buildInfoRow('Special Conditions', terms.specialConditions!),
        ],
      ),
    );
  }

  Widget _buildQualitySpecsCard(FinalDealReviewData deal) {
    final specs = deal.currentTerms.qualityParameters;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.microscope, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Agreed Quality Parameters',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...specs.map((q) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.parameterName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        if (q.tolerance != null)
                          Text(
                            'Tolerance: ${q.tolerance}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${q.targetValue} ${q.unit ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      if (q.isMandatory) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Mandatory',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBrokerDeskCard(FinalDealReviewData deal) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.briefcase,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Broker Desk: ${deal.brokerName}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            deal.brokerAgency,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
            ),
          ),
          if (deal.brokerNotes != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Notes: ${deal.brokerNotes}',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTradeMilestonesCard(FinalDealReviewData deal) {
    // Phase G Requirement: Deal confirmation does NOT mean invoicing, payment, or dispatch is complete.
    final isConfirmed = deal.isConfirmed;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.milestone, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Trade Execution Lifecycle',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMilestoneStep(
            stepNumber: 1,
            title: 'Deal Confirmation',
            subtitle: isConfirmed
                ? 'Completed — Confirmed by Buyer'
                : 'Action Required: Explicit Confirmation',
            isComplete: isConfirmed,
            isActive: !isConfirmed,
          ),
          _buildMilestoneStep(
            stepNumber: 2,
            title: 'Contract Issuance & Trade Slip',
            subtitle: isConfirmed
                ? 'In Progress — Broker desk compiling legal SoDA'
                : 'Pending Deal Confirmation',
            isComplete: false,
            isActive: isConfirmed,
          ),
          _buildMilestoneStep(
            stepNumber: 3,
            title: 'Weighbridge & Dispatch Notice',
            subtitle: 'Not Started — Pending seller dispatch report',
            isComplete: false,
            isActive: false,
          ),
          _buildMilestoneStep(
            stepNumber: 4,
            title: 'Quality Acceptance & Settlement',
            subtitle: 'Not Started — Pending delivery & slip verification',
            isComplete: false,
            isActive: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneStep({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isComplete,
    required bool isActive,
  }) {
    final color = isComplete
        ? AppColors.success
        : isActive
            ? AppColors.primary
            : AppColors.textMutedLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color.withValues(alpha: 0.15),
            child: isComplete
                ? const Icon(LucideIcons.check, size: 14, color: AppColors.success)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isComplete || isActive
                        ? AppColors.textPrimaryLight
                        : AppColors.textMutedLight,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isComplete
                        ? AppColors.success
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(FinalDealReviewData deal) {
    if (deal.isConfirmed) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: AppColors.success.withValues(alpha: 0.1),
        child: Row(
          children: [
            const Icon(LucideIcons.checkCircle,
                color: AppColors.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Deal Snapshot v${deal.versionNumber} Officially Confirmed. Broker desk is compiling the legal trade contract.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (deal.isAmendmentRequired) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: AppColors.secondary.withValues(alpha: 0.1),
        child: Row(
          children: [
            const Icon(LucideIcons.alertCircle,
                color: AppColors.secondary, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Amendment Requested. Awaiting revised commercial proposal snapshot from the Broker desk.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: AppButton(
              label: 'Request Amendment',
              variant: AppButtonVariant.outline,
              onPressed: _isSubmitting ? null : _handleRequestAmendment,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: AppButton(
              label: 'Confirm Deal',
              variant: AppButtonVariant.primary,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _handleConfirmDeal,
            ),
          ),
        ],
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
