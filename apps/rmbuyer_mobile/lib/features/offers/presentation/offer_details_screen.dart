import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/offers_repository.dart';
import '../domain/buyer_offer_model.dart';
import '../domain/offer_inputs.dart';

/// Screen displaying complete commercial offer terms, negotiation rounds history,
/// attached documents, and interactive counter-offer, accept, and decline actions.
/// Strict Counterparty Shield: Direct seller identities and contacts remain strictly confidential.
class OfferDetailsScreen extends StatefulWidget {
  final String offerId;
  final BuyerOffer? initialOffer;
  final OffersRepository? repository;

  const OfferDetailsScreen({
    super.key,
    required this.offerId,
    this.initialOffer,
    this.repository,
  });

  @override
  State<OfferDetailsScreen> createState() => _OfferDetailsScreenState();
}

class _OfferDetailsScreenState extends State<OfferDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final OffersRepository _repo;
  late final TabController _tabController;

  BuyerOffer? _offer;
  bool _isLoading = true;
  bool _isUnavailable = false;
  String? _errorMessage;
  bool _isBrokerMessageExpanded = false;

  final currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? OffersRepository();
    _tabController = TabController(length: 3, vsync: this);

    if (widget.initialOffer != null) {
      _offer = widget.initialOffer;
      _isLoading = false;
    }

    _loadOfferDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOfferDetails() async {
    // Only set full-screen loading if we don't already have an initial offer
    if (_offer == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _isUnavailable = false;
      });
    }

    try {
      final item = await _repo.getOfferById(widget.offerId);
      if (!mounted) return;

      if (item != null) {
        setState(() {
          _offer = item;
          _isLoading = false;
          _isUnavailable = false;
          _errorMessage = null;
        });
      } else if (_offer != null) {
        // Retain existing offer
        setState(() {
          _isLoading = false;
          _isUnavailable = false;
        });
      } else {
        setState(() {
          _offer = null;
          _isLoading = false;
          _isUnavailable = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_offer != null) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _offer = null;
          _isLoading = false;
          _isUnavailable = false;
          _errorMessage =
              'We couldn\'t fetch the latest information. Please check your internet connection and try again.';
        });
      }
    }
  }

  void _navigateBack() {
    try {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go('/offers');
    } catch (_) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  int _calculateRemainingDays(DateTime? validUntil) {
    if (validUntil == null) return 3;
    final diff = validUntil.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  String _formatQualitySpecs(List<OfferQualitySpec> specs) {
    if (specs.isEmpty) return 'Grade A, Moisture ≤ 14%';
    return specs
        .map((s) => '${s.parameterName} ${s.tolerance ?? s.targetValue}')
        .join(', ');
  }

  // ============================================================================
  // COMMERCIAL ACTIONS: COUNTER-OFFER, ACCEPT, DECLINE
  // ============================================================================

  void _showCounterOfferDialog(BuyerOffer offer) {
    final rateController =
        TextEditingController(text: offer.offeredPrice.toStringAsFixed(0));
    final qtyController =
        TextEditingController(text: offer.offeredQuantity.toStringAsFixed(0));
    final notesController = TextEditingController();
    String? dialogError;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAF8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current Offered Rate',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${currencyFormat.format(offer.offeredPrice)} / ${offer.unit}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Offered Volume',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${offer.offeredQuantity} ${offer.unit}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('counter-rate-input'),
                      controller: rateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Your Target Rate (₹ / ${offer.unit}) *',
                        prefixText: '₹ ',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('counter-qty-input'),
                      controller: qtyController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Quantity (${offer.unit}) *',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('counter-notes-input'),
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Commercial Note for Broker Desk (Optional)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 2,
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        dialogError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('counter-submit-btn'),
                        icon: const Icon(LucideIcons.send, size: 16),
                        label: Text(isSubmitting
                            ? 'Submitting to Broker...'
                            : 'Confirm & Submit to Broker'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF064E3B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final rate =
                                    double.tryParse(rateController.text.trim());
                                final qty =
                                    double.tryParse(qtyController.text.trim());

                                if (rate == null || rate <= 0) {
                                  setModalState(() => dialogError =
                                      'Please enter a valid target rate.');
                                  return;
                                }
                                if (qty == null || qty <= 0) {
                                  setModalState(() => dialogError =
                                      'Please enter a valid quantity.');
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  dialogError = null;
                                });

                                final scaffoldMessenger =
                                    ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(modalContext);

                                try {
                                  final updated =
                                      await _repo.submitCounterOffer(
                                    CounterOfferInput(
                                      proposalId: offer.id,
                                      expectedVersionNumber:
                                          offer.versionNumber,
                                      counterPrice: rate,
                                      counterQuantity: qty,
                                      buyerNotes: notesController.text
                                              .trim()
                                              .isNotEmpty
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
                                        'Counter-offer submitted to broker desk. Round ${updated.versionNumber} active.',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } catch (err) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    dialogError = err
                                        .toString()
                                        .replaceAll('Exception: ', '')
                                        .replaceAll('StateError: ', '');
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
                  Icon(LucideIcons.checkCircle2,
                      color: AppColors.success, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Accept Offer Terms',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You are accepting the commercial terms for ${offer.commodityName}:',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rate: ₹${offer.offeredPrice.toStringAsFixed(0)} / ${offer.unit}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text('Quantity: ${offer.offeredQuantity} ${offer.unit}'),
                          const SizedBox(height: 2),
                          Text(
                            'Total Value: ${currencyFormat.format(offer.totalEstimatedValue)}',
                          ),
                          const SizedBox(height: 2),
                          Text('Delivery Terms: ${offer.deliveryTerms}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAF8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.info,
                              size: 14, color: Color(0xFF1E5E3A)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Legal notice: Accepting this commercial proposal confirms price and volume agreement with your broker desk. Final deal confirmation and contract generation will be mediated by your broker.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryLight,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        dialogError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('offer-confirm-accept-btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF064E3B),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });

                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
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
                                content: Text(
                                  'Commercial offer accepted. Broker desk notified for deal confirmation.',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (err) {
                            setDialogState(() {
                              isSubmitting = false;
                              dialogError = err
                                  .toString()
                                  .replaceAll('Exception: ', '')
                                  .replaceAll('StateError: ', '');
                            });
                          }
                        },
                  child: Text(
                    isSubmitting ? 'Confirming...' : 'Confirm Acceptance',
                  ),
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
                  Text(
                    'Decline Offer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please indicate the commercial reason for declining this proposal. This feedback is logged for broker records.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      decoration: const InputDecoration(
                        labelText: 'Decline Reason *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      isExpanded: true,
                      items: reasons.map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(r, style: const TextStyle(fontSize: 12)),
                        );
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      maxLines: 2,
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        dialogError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('offer-confirm-reject-btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });

                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
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
                                content: Text(
                                  'Commercial proposal declined. Broker desk updated.',
                                ),
                                backgroundColor: AppColors.charcoal,
                              ),
                            );
                          } catch (err) {
                            setDialogState(() {
                              isSubmitting = false;
                              dialogError = err
                                  .toString()
                                  .replaceAll('Exception: ', '')
                                  .replaceAll('StateError: ', '');
                            });
                          }
                        },
                  child: Text(
                    isSubmitting ? 'Declining...' : 'Confirm Decline',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // MAIN BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final title = _offer?.commodityName ??
        widget.initialOffer?.commodityName ??
        'Proposal Details';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _navigateBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAF8),
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          leading: IconButton(
            key: const Key('offer-details-back-button'),
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: _navigateBack,
          ),
          actions: [
            IconButton(
              key: const Key('offer-details-refresh-button'),
              icon: const Icon(LucideIcons.rotateCw),
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _loadOfferDetails,
            ),
          ],
          bottom: (_isLoading || _isUnavailable || _errorMessage != null || _offer == null)
              ? null
              : TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF1E5E3A),
                  unselectedLabelColor: AppColors.textSecondaryLight,
                  indicatorColor: const Color(0xFF1E5E3A),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(key: Key('tab-details'), text: 'Details'),
                    Tab(key: Key('tab-history'), text: 'Negotiation History'),
                    Tab(key: Key('tab-documents'), text: 'Documents'),
                  ],
                ),
        ),
        bottomNavigationBar:
            (_isLoading || _isUnavailable || _errorMessage != null || _offer == null)
                ? null
                : _buildBottomActionBar(_offer!),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_isUnavailable || _offer == null) {
      return _buildUnavailableState();
    }

    final offer = _offer!;
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDetailsTab(offer),
        _buildNegotiationHistoryTab(offer),
        _buildDocumentsTab(offer),
      ],
    );
  }

  // ============================================================================
  // STATE VIEWS (Loading, Error, Unavailable)
  // ============================================================================

  Widget _buildLoadingState() {
    return Center(
      key: const Key('offer-details-loading-state'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.fileText,
                size: 34,
                color: Color(0xFF1E5E3A),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading proposal details...',
              key: Key('loading-title-text'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please wait while we fetch the latest offer and negotiation details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      key: const Key('offer-details-error-state'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.alertCircle,
                size: 34,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Failed to load proposal details',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We couldn\'t fetch the latest information. Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  key: const Key('offer-error-retry-button'),
                  onPressed: _loadOfferDetails,
                  icon: const Icon(LucideIcons.rotateCw, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF064E3B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  key: const Key('offer-error-back-button'),
                  onPressed: _navigateBack,
                  icon: const Icon(LucideIcons.arrowLeft, size: 16),
                  label: const Text('Back to Offers'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimaryLight,
                    side: const BorderSide(color: AppColors.borderLight),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailableState() {
    return Center(
      key: const Key('offer-details-unavailable-state'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.fileText,
                size: 34,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Proposal Unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This proposal is no longer available or you don\'t have permission to view it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                key: const Key('offer-unavailable-back-button'),
                onPressed: _navigateBack,
                icon: const Icon(LucideIcons.arrowLeft, size: 16),
                label: const Text('Back to Offers'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF064E3B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 1: DETAILS TAB
  // ============================================================================

  Widget _buildDetailsTab(BuyerOffer offer) {
    return SingleChildScrollView(
      key: const Key('offer-details-tab-content'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Commodity Overview Card
          _buildCommodityOverviewCard(offer),
          const SizedBox(height: 18),

          // Offer Details 2x2 Grid Section
          const Text(
            'Offer Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 10),
          _buildOfferDetailsGrid(offer),
          const SizedBox(height: 18),

          // Terms & Conditions Section
          const Text(
            'Terms & Conditions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 10),
          _buildTermsAndConditionsCard(offer),
          const SizedBox(height: 18),

          // Broker Message Expandable Tile
          _buildBrokerMessageTile(offer),
        ],
      ),
    );
  }

  Widget _buildCommodityOverviewCard(BuyerOffer offer) {
    final daysRemaining = _calculateRemainingDays(offer.validUntil);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Thumbnail + Commodity/Grade + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CommodityThumbnail(commodityName: offer.commodityName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.commodityName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offer.gradeName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: offer.status),
            ],
          ),
          const Divider(height: 24),

          // Requirement reference row with "View Requirement >"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Requirement\n${offer.requirementDisplayId}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryLight,
                  height: 1.3,
                ),
              ),
              InkWell(
                key: const Key('offer-view-requirement-link'),
                onTap: () {
                  if (offer.requirementId.isNotEmpty) {
                    context.push('/requirements/${offer.requirementId}');
                  }
                },
                child: const Row(
                  children: [
                    Text(
                      'View Requirement',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E5E3A),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 14,
                      color: Color(0xFF1E5E3A),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Validity & Broker desk info
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.clock,
                      size: 15,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        offer.validUntil != null
                            ? 'Valid till\n${DateFormat('dd MMM yyyy').format(offer.validUntil!)} ($daysRemaining days left)'
                            : 'Valid till\nPrompt Dispatch',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondaryLight,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.landmark,
                      size: 15,
                      color: Color(0xFF1E5E3A),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Offer from\n${offer.brokerName}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondaryLight,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfferDetailsGrid(BuyerOffer offer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Offered Rate',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currencyFormat.format(offer.offeredPrice)} / ${offer.unit}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E5E3A),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Offered Quantity',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${offer.offeredQuantity} ${offer.unit}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Value',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(offer.totalEstimatedValue),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Location',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer.deliveryLocation,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermsAndConditionsCard(BuyerOffer offer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTermRow(
            icon: LucideIcons.truck,
            title: 'Delivery Terms',
            value: offer.deliveryTerms,
          ),
          const Divider(height: 20),
          _buildTermRow(
            icon: LucideIcons.creditCard,
            title: 'Payment Terms',
            value: offer.paymentTerms,
          ),
          const Divider(height: 20),
          _buildTermRow(
            icon: LucideIcons.badgeCheck,
            title: 'Quality Specification',
            value: _formatQualitySpecs(offer.qualitySpecs),
          ),
          const Divider(height: 20),
          _buildTermRow(
            icon: LucideIcons.clock,
            title: 'Other Terms',
            value: offer.specialConditions ?? 'As per mandi standards',
          ),
        ],
      ),
    );
  }

  Widget _buildTermRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondaryLight),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrokerMessageTile(BuyerOffer offer) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isBrokerMessageExpanded,
          onExpansionChanged: (val) {
            setState(() {
              _isBrokerMessageExpanded = val;
            });
          },
          leading: const Icon(
            LucideIcons.messageSquare,
            size: 18,
            color: Color(0xFF1E5E3A),
          ),
          title: const Text(
            'Broker Message',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAF8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  offer.brokerNotes ??
                      'Standard commercial proposal mediated through licensed broker desk. All quotes and terms remain strictly confidential.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 2: NEGOTIATION HISTORY TAB
  // ============================================================================

  Widget _buildNegotiationHistoryTab(BuyerOffer offer) {
    final rounds = offer.negotiationRounds;

    if (rounds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No negotiation rounds recorded. Initial proposal received from broker desk.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      key: const Key('offer-history-tab-content'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rounds.length,
            itemBuilder: (context, i) {
              final round = rounds[i];
              final isLast = i == rounds.length - 1;
              final isBuyer = round.actorRole == 'buyer';

              Color dotColor;
              String title;
              if (round.versionNumber == 1) {
                dotColor = const Color(0xFFF59E0B);
                title = 'Broker Proposed Offer';
              } else if (isBuyer) {
                dotColor = const Color(0xFF2563EB);
                title = 'You Countered';
              } else {
                dotColor = const Color(0xFF1E5E3A);
                title = 'Broker Replied';
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline Line & Dot
                    Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Round Content Card
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  if (round.status.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: round.status == 'Countered'
                                            ? const Color(0xFFE8F5E9)
                                            : (round.isCurrent
                                                ? const Color(0xFFFEF3C7)
                                                : const Color(0xFFF1F5F9)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        round.status == 'Countered'
                                            ? 'PENDING'
                                            : (round.isCurrent
                                                ? 'NEW'
                                                : round.status.toUpperCase()),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: round.status == 'Countered'
                                              ? const Color(0xFF1E5E3A)
                                              : (round.isCurrent
                                                  ? const Color(0xFFD97706)
                                                  : AppColors.textSecondaryLight),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a')
                                    .format(round.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                              const Divider(height: 16),
                              Text(
                                '${currencyFormat.format(round.proposedPrice)} / ${offer.unit}  |  ${round.proposedQuantity} ${offer.unit}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E5E3A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total Value: ${currencyFormat.format(round.proposedPrice * round.proposedQuantity)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Valid till: ${round.deliveryDate ?? (offer.validUntil != null ? DateFormat('dd MMM yyyy').format(offer.validUntil!) : '01 Nov 2026')}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                              if (round.notes != null &&
                                  round.notes!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Note: ${round.notes}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.textMutedLight,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 3: DOCUMENTS TAB
  // ============================================================================

  Widget _buildDocumentsTab(BuyerOffer offer) {
    final docs = [
      {'name': 'Offer Sheet', 'type': 'PDF · 245 KB', 'color': const Color(0xFFEA4335)},
      {'name': 'Quality Specification', 'type': 'PDF · 312 KB', 'color': const Color(0xFFF59E0B)},
      {'name': 'Other Terms', 'type': 'PDF · 180 KB', 'color': const Color(0xFFEA4335)},
    ];

    return SingleChildScrollView(
      key: const Key('offer-documents-tab-content'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attached Documents',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 12),
          ...docs.map((doc) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (doc['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.fileText,
                    color: doc['color'] as Color,
                    size: 20,
                  ),
                ),
                title: Text(
                  doc['name'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  doc['type'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    LucideIcons.arrowDownToLine,
                    size: 18,
                    color: Color(0xFF1E5E3A),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloading ${doc['name']}...'),
                        backgroundColor: const Color(0xFF1E5E3A),
                      ),
                    );
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================================
  // BOTTOM ACTION BAR
  // ============================================================================

  Widget _buildBottomActionBar(BuyerOffer offer) {
    if (!offer.isActionable) {
      String bannerMessage;
      IconData bannerIcon;
      Color bannerColor;

      if (offer.status.toLowerCase() == 'accepted') {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.checkCircle2,
                      size: 20, color: AppColors.success),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Proposal Accepted. Broker desk preparing final trade deal.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF064E3B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(LucideIcons.fileCheck, size: 16),
                  label: const Text(
                    'Review & Confirm Deal',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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
        bannerMessage =
            'Proposal Rejected. No further actions permitted on this offer.';
        bannerIcon = LucideIcons.xCircle;
        bannerColor = AppColors.charcoal;
      } else {
        bannerMessage =
            'Offer Validity Expired. Contact broker desk to request a refreshed quote.';
        bannerIcon = LucideIcons.clockAlert;
        bannerColor = AppColors.error;
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(bannerIcon, size: 20, color: bannerColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bannerMessage,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: bannerColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 1. Make Counter Offer (Outlined Green)
            Expanded(
              flex: 12,
              child: OutlinedButton(
                key: const Key('offer-make-counter-btn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F5132),
                  side: const BorderSide(color: Color(0xFF0F5132)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _showCounterOfferDialog(offer),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Make Counter Offer',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 2. Accept Offer (Solid Green)
            Expanded(
              flex: 10,
              child: ElevatedButton.icon(
                key: const Key('offer-accept-btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF064E3B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(LucideIcons.check, size: 15),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Accept Offer',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                onPressed: () => _showAcceptConfirmationDialog(offer),
              ),
            ),
            const SizedBox(width: 8),

            // 3. Decline Offer (Outlined Red)
            Expanded(
              flex: 9,
              child: OutlinedButton(
                key: const Key('offer-decline-btn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFDC2626)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _showRejectConfirmationDialog(offer),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Decline Offer',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommodityThumbnail extends StatelessWidget {
  final String commodityName;

  const _CommodityThumbnail({required this.commodityName});

  @override
  Widget build(BuildContext context) {
    final lower = commodityName.toLowerCase();
    Color bgColor;
    Color iconColor;
    IconData icon;

    if (lower.contains('maize') || lower.contains('corn')) {
      bgColor = const Color(0xFFFFF8E1);
      iconColor = const Color(0xFFF57F17);
      icon = LucideIcons.wheat;
    } else if (lower.contains('mustard')) {
      bgColor = const Color(0xFFFFFDE7);
      iconColor = const Color(0xFFFBC02D);
      icon = LucideIcons.flower2;
    } else if (lower.contains('rice') ||
        lower.contains('paddy') ||
        lower.contains('bran')) {
      bgColor = const Color(0xFFE8F5E9);
      iconColor = const Color(0xFF388E3C);
      icon = LucideIcons.sprout;
    } else if (lower.contains('wheat') ||
        lower.contains('chana') ||
        lower.contains('gram') ||
        lower.contains('soybean') ||
        lower.contains('soya')) {
      bgColor = const Color(0xFFEFEBE9);
      iconColor = const Color(0xFF6D4C41);
      icon = LucideIcons.wheat;
    } else {
      bgColor = AppColors.primaryContainer;
      iconColor = AppColors.primary;
      icon = LucideIcons.package;
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 26,
          color: iconColor,
        ),
      ),
    );
  }
}
