import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/offers_repository.dart';
import '../domain/buyer_offer_model.dart';
import '../domain/offer_inputs.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';

/// Screen displaying complete commercial offer terms, immutable negotiation rounds history,
/// and interactive counter-offer, accept, and reject actions.
/// Strict Counterparty Shield: Direct seller identities and contacts remain strictly confidential.
class OfferDetailsScreen extends StatefulWidget {
  final String offerId;
  final BuyerOffer? initialOffer;
  final OffersRepository? repository;
  final ContactLauncherService? contactLauncher;

  const OfferDetailsScreen({
    super.key,
    required this.offerId,
    this.initialOffer,
    this.repository,
    this.contactLauncher,
  });

  @override
  State<OfferDetailsScreen> createState() => _OfferDetailsScreenState();
}

class _OfferDetailsScreenState extends State<OfferDetailsScreen> {
  late final OffersRepository _repo;
  late final ContactLauncherService _contactLauncher;

  BuyerOffer? _offer;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? OffersRepository();
    _contactLauncher = widget.contactLauncher ?? ContactLauncherService();
    _loadOfferDetails();
  }

  Future<void> _loadOfferDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final item = await _repo.getOfferById(widget.offerId);
      if (!mounted) return;
      setState(() {
        _offer = item ?? widget.initialOffer;
        _isLoading = false;
        if (_offer == null) {
          _errorMessage = 'Commercial proposal could not be found or access was restricted.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _offer = widget.initialOffer;
        _isLoading = false;
        if (_offer == null) {
          _errorMessage = 'Failed to load commercial offer details: $e';
        }
      });
    }
  }

  // ============================================================================
  // COMMERCIAL ACTIONS: COUNTER-OFFER, ACCEPT, REJECT
  // ============================================================================

  void _showCounterOfferDialog(BuyerOffer offer) {
    final rateController = TextEditingController(text: offer.offeredPrice.toStringAsFixed(0));
    final qtyController = TextEditingController(text: offer.offeredQuantity.toStringAsFixed(0));
    final notesController = TextEditingController();
    String? dialogError;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Submit Counter-Offer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Propose revised commercial terms to your broker desk. Round ${offer.versionNumber + 1} will be appended to the permanent negotiation ledger.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    const Divider(height: 24),

                    // Current Benchmark Reference Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Current Broker Rate', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                              Text('₹${offer.offeredPrice.toStringAsFixed(0)} / ${offer.unit}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Offered Quantity', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                              Text('${offer.offeredQuantity} ${offer.unit}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (dialogError != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.errorBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogError!,
                                style: const TextStyle(fontSize: 12, color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Counter Rate Input
                    AppTextField(
                      label: 'Your Proposed Rate (₹ / ${offer.unit}) *',
                      controller: rateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: const Icon(LucideIcons.indianRupee, size: 16),
                      hint: 'e.g. 22200',
                    ),
                    const SizedBox(height: 14),

                    // Counter Quantity Input
                    AppTextField(
                      label: 'Proposed Quantity (${offer.unit}) *',
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: const Icon(LucideIcons.scale, size: 16),
                      hint: 'e.g. 100',
                    ),
                    const SizedBox(height: 14),

                    // Commercial Notes / Delivery Terms
                    AppTextField(
                      label: 'Commercial Remarks to Broker Desk',
                      controller: notesController,
                      maxLines: 2,
                      hint: 'e.g. Subject to delivery by 25th Oct at Khanna Mill.',
                    ),
                    const SizedBox(height: 20),

                    // Submit CTA
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: isSubmitting ? 'Submitting Counter-Offer...' : 'Confirm & Submit to Broker',
                        icon: LucideIcons.send,
                        isLoading: isSubmitting,
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final parsedPrice = double.tryParse(rateController.text.trim()) ?? 0.0;
                                final parsedQty = double.tryParse(qtyController.text.trim()) ?? 0.0;

                                if (parsedPrice <= 0) {
                                  setModalState(() {
                                    dialogError = 'Please enter a valid counter rate greater than zero.';
                                  });
                                  return;
                                }

                                if (parsedQty <= 0) {
                                  setModalState(() {
                                    dialogError = 'Please enter a valid counter quantity greater than zero.';
                                  });
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  dialogError = null;
                                });

                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(modalContext);

                                try {
                                  final updated = await _repo.submitCounterOffer(
                                    CounterOfferInput(
                                      proposalId: offer.id,
                                      expectedVersionNumber: offer.versionNumber,
                                      counterPrice: parsedPrice,
                                      counterQuantity: parsedQty,
                                      buyerNotes: notesController.text.trim().isNotEmpty
                                          ? notesController.text.trim()
                                          : null,
                                    ),
                                  );

                                  navigator.pop();
                                  if (!mounted) return;
                                  setState(() {
                                    _offer = updated;
                                  });

                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Counter-Offer Round ${updated.versionNumber} successfully submitted to ${offer.brokerName}.',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } catch (err) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    dialogError = err.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '');
                                  });
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAcceptConfirmationDialog(BuyerOffer offer) {
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 22),
                  SizedBox(width: 8),
                  Text('Accept Offer Terms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You are accepting the commercial terms for ${offer.commodityName}:',
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryLight),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rate: ₹${offer.offeredPrice.toStringAsFixed(0)} / ${offer.unit}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('Quantity: ${offer.offeredQuantity} ${offer.unit}'),
                          Text('Total Value: ₹${(offer.offeredPrice * offer.offeredQuantity).toStringAsFixed(0)}'),
                          Text('Delivery Terms: ${offer.deliveryTerms}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.info, size: 14, color: AppColors.primary),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Legal notice: Accepting this commercial proposal confirms price and volume agreement with your broker desk. Final deal confirmation and contract generation will be mediated by your broker.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(dialogError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });

                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(dialogContext);

                          try {
                            final updated = await _repo.acceptOffer(
                              AcceptOfferInput(
                                proposalId: offer.id,
                                expectedVersionNumber: offer.versionNumber,
                              ),
                            );

                            navigator.pop();
                            if (!mounted) return;
                            setState(() {
                              _offer = updated;
                            });

                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Commercial offer accepted. Broker desk notified for deal confirmation.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (err) {
                            setDialogState(() {
                              isSubmitting = false;
                              dialogError = err.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '');
                            });
                          }
                        },
                  child: Text(isSubmitting ? 'Confirming...' : 'Confirm Acceptance', style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRejectConfirmationDialog(BuyerOffer offer) {
    String selectedReason = 'Rate above budget / unacceptable';
    final notesController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;

    final reasons = [
      'Rate above budget / unacceptable',
      'Delivery schedule does not match requirement',
      'Quality specifications / moisture variance',
      'Sourced from alternative mandi',
      'Procurement requirement cancelled',
      'Other commercial reasons',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(LucideIcons.xCircle, color: AppColors.error, size: 22),
                  SizedBox(width: 8),
                  Text('Reject Offer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please indicate the commercial reason for rejecting this proposal. This feedback is logged for broker records.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      decoration: const InputDecoration(
                        labelText: 'Rejection Reason *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      isExpanded: true,
                      items: reasons.map((r) {
                        return DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedReason = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Additional Notes (Optional)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      maxLines: 2,
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(dialogError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });

                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(dialogContext);

                          try {
                            final updated = await _repo.rejectOffer(
                              RejectOfferInput(
                                proposalId: offer.id,
                                expectedVersionNumber: offer.versionNumber,
                                reason: selectedReason,
                                notes: notesController.text.trim().isNotEmpty
                                    ? notesController.text.trim()
                                    : null,
                              ),
                            );

                            navigator.pop();
                            if (!mounted) return;
                            setState(() {
                              _offer = updated;
                            });

                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Commercial proposal rejected. Broker desk updated.'),
                                backgroundColor: AppColors.charcoal,
                              ),
                            );
                          } catch (err) {
                            setDialogState(() {
                              isSubmitting = false;
                              dialogError = err.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '');
                            });
                          }
                        },
                  child: Text(isSubmitting ? 'Rejecting...' : 'Confirm Rejection', style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // UI BUILDERS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr(Tr.titleProposalDetails))),
        body: const AppLoadingIndicator(
          message: 'Retrieving commercial terms and negotiation ledger...',
        ),
      );
    }

    if (_errorMessage != null || _offer == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr(Tr.titleProposalDetails))),
        body: AppErrorState(
          message: _errorMessage ?? 'Offer not found.',
          onRetry: _loadOfferDetails,
        ),
      );
    }

    final offer = _offer!;
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(offer.commodityName),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCw),
            tooltip: 'Refresh',
            onPressed: _loadOfferDetails,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(offer),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Status Header Card
              _buildTopHeaderCard(offer),
              const SizedBox(height: 16),

              // Commercial Terms Card
              _buildCommercialOverviewCard(offer, currencyFormat),
              const SizedBox(height: 16),

              // Delivery & Logistics Card
              _buildDeliveryTermsCard(offer),
              const SizedBox(height: 16),

              // Quality Specifications Card
              _buildQualitySpecsCard(offer),
              const SizedBox(height: 16),

              // Broker Desk Card with Direct Mediation CTA
              _buildBrokerDeskCard(offer),
              const SizedBox(height: 16),

              // Counterparty Shield Banner
              _buildCounterpartyShieldCard(),
              const SizedBox(height: 20),

              // Negotiation History & Rounds Ledger (Phase E)
              _buildNegotiationLedgerCard(offer, currencyFormat),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeaderCard(BuyerOffer offer) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Proposal Version ${offer.versionNumber}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              StatusBadge(status: offer.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            offer.commodityName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryLight,
            ),
          ),
          Text(
            offer.gradeName,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  'Req: ${offer.requirementDisplayId}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              if (offer.validUntil != null)
                Row(
                  children: [
                    Icon(
                      LucideIcons.clock,
                      size: 14,
                      color: offer.isExpired ? AppColors.error : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      offer.isExpired
                          ? 'Offer Expired'
                          : 'Valid till ${DateFormat('dd MMM, hh:mm a').format(offer.validUntil!)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: offer.isExpired ? AppColors.error : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommercialOverviewCard(BuyerOffer offer, NumberFormat currencyFormat) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Commercial Proposal Terms',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Offered Rate',
                  '${currencyFormat.format(offer.offeredPrice)} / ${offer.unit}',
                  isHighlight: true,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Quantity',
                  '${offer.offeredQuantity} ${offer.unit}',
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Estimated Value',
                  currencyFormat.format(offer.totalEstimatedValue),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildDetailRow('Payment Terms', offer.paymentTerms),
          const SizedBox(height: 8),
          _buildDetailRow('Delivery Terms', offer.deliveryTerms),

          if (offer.applicableCharges.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'Applicable Trade Charges (Transparent Disclosure)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 8),
            ...offer.applicableCharges.map((charge) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(charge.name, style: const TextStyle(fontSize: 12)),
                    Text('₹${charge.rate.toStringAsFixed(0)} / ${offer.unit}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryTermsCard(BuyerOffer offer) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Logistics & Delivery Schedule',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Delivery Destination', offer.deliveryLocation),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Target Delivery Window',
            offer.deliveryDate != null ? DateFormat('dd MMMM yyyy').format(offer.deliveryDate!) : 'Immediate / Prompt Dispatch',
          ),
          const SizedBox(height: 8),
          _buildDetailRow('Packaging Specification', offer.packagingType),
          if (offer.specialConditions != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Special Conditions', offer.specialConditions!),
          ],
        ],
      ),
    );
  }

  Widget _buildQualitySpecsCard(BuyerOffer offer) {
    if (offer.qualitySpecs.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quality Specifications & Mandi Parameters',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...offer.qualitySpecs.map((spec) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(spec.parameterName, style: const TextStyle(fontSize: 12)),
                  Text(
                    '${spec.targetValue}${spec.unit != null ? ' ${spec.unit}' : ''}${spec.tolerance != null ? ' (${spec.tolerance})' : ''}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBrokerDeskCard(BuyerOffer offer) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assigned Mandi Broker Desk',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            offer.brokerName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
          if (offer.brokerNotes != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Text(
                'Broker Desk Notes: ${offer.brokerNotes!}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondaryLight),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.phone, size: 16),
                  label: const Text('Call Broker'),
                  onPressed: () {
                    _contactLauncher.launchCall('+919876500001');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.messageSquare, size: 16),
                  label: const Text('WhatsApp'),
                  onPressed: () {
                    _contactLauncher.launchWhatsApp(
                      '+919876500001',
                      prefilledMessage: 'Inquiring regarding Proposal ${offer.id} for ${offer.commodityName}.',
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterpartyShieldCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.shieldCheck, size: 18, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Counterparty Shield Active: Commercial negotiations are mediated through your authorized broker desk. Direct seller contact details and identity remain strictly confidential to prevent price manipulation and contract circumvention.',
              style: TextStyle(fontSize: 11, color: AppColors.primaryDark, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNegotiationLedgerCard(BuyerOffer offer, NumberFormat currencyFormat) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Negotiation History & Rounds Ledger',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${offer.negotiationRounds.length} Rounds',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Auditable, append-only history of commercial proposal iterations.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
          ),
          const Divider(height: 20),

          if (offer.negotiationRounds.isEmpty)
            const Text('No prior rounds recorded.', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: offer.negotiationRounds.length,
              separatorBuilder: (context, index) => const Divider(height: 20),
              itemBuilder: (context, index) {
                final round = offer.negotiationRounds[index];
                final isBuyer = round.actorRole == 'buyer';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isBuyer ? const Color(0xFF7C3AED).withValues(alpha: 0.15) : AppColors.primaryContainer,
                      child: Icon(
                        isBuyer ? LucideIcons.userCheck : LucideIcons.briefcase,
                        size: 14,
                        color: isBuyer ? const Color(0xFF7C3AED) : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Round ${round.versionNumber}: ${round.proposerName}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              StatusBadge(
                                status: round.status,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Proposed: ${currencyFormat.format(round.proposedPrice)} / ${offer.unit} (${round.proposedQuantity} ${offer.unit})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
                          ),
                          if (round.notes != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              round.notes!,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(round.createdAt),
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget? _buildBottomActionBar(BuyerOffer offer) {
    if (!offer.isActionable) {
      String bannerMessage;
      IconData bannerIcon;
      Color bannerColor;

      if (offer.status.toLowerCase() == 'accepted') {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.checkCircle2, size: 20, color: AppColors.success),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Proposal Accepted. Broker desk preparing final trade deal.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(LucideIcons.fileCheck, size: 16),
                  label: const Text('Review & Confirm Deal', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    try {
                      context.push('/deals/${offer.id}/confirm');
                    } catch (_) {}
                  },
                ),
              ),
            ],
          ),
        );
      }

      if (offer.status.toLowerCase() == 'rejected') {
        bannerMessage = 'Proposal Rejected. No further actions permitted on this offer.';
        bannerIcon = LucideIcons.xCircle;
        bannerColor = AppColors.charcoal;
      } else {
        bannerMessage = 'Offer Validity Expired. Contact broker desk to request a refreshed quote.';
        bannerIcon = LucideIcons.clockAlert;
        bannerColor = AppColors.error;
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Icon(bannerIcon, size: 20, color: bannerColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bannerMessage,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: bannerColor),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Reject button
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onPressed: () => _showRejectConfirmationDialog(offer),
            child: const Text('Reject'),
          ),
          const SizedBox(width: 8),

          // Counter-Offer button
          Expanded(
            child: AppButton(
              label: 'Counter-Offer',
              icon: LucideIcons.refreshCcw,
              variant: AppButtonVariant.primary,
              onPressed: () => _showCounterOfferDialog(offer),
            ),
          ),
          const SizedBox(width: 8),

          // Accept button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showAcceptConfirmationDialog(offer),
            child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 16 : 14,
            fontWeight: FontWeight.w700,
            color: isHighlight ? AppColors.primary : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight)),
        ),
      ],
    );
  }
}
