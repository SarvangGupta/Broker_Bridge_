import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/work_repository.dart';
import '../../domain/requirement_model.dart';
import '../../domain/requirement_negotiation_model.dart';
import '../controllers/requirements_controller.dart';

/// Modal bottom sheet allowing authorized brokers to initiate negotiation
/// and submit commercial proposals for buyer requirements.
class NegotiateRequirementSheet extends ConsumerStatefulWidget {
  final RequirementItem requirement;

  const NegotiateRequirementSheet({
    super.key,
    required this.requirement,
  });

  static Future<bool?> show(
    BuildContext context, {
    required RequirementItem requirement,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NegotiateRequirementSheet(
        requirement: requirement,
      ),
    );
  }

  @override
  ConsumerState<NegotiateRequirementSheet> createState() => _NegotiateRequirementSheetState();
}

class _NegotiateRequirementSheetState extends ConsumerState<NegotiateRequirementSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _deliveryTermsController;
  late TextEditingController _paymentTermsController;
  late TextEditingController _packagingController;
  late TextEditingController _deliveryLocationController;
  late TextEditingController _notesController;

  late String _priceBasis;
  late DateTime _deliveryDate;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  RequirementNegotiationData? _negotiationData;

  final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final req = widget.requirement;

    _priceController = TextEditingController(text: req.targetPrice > 0 ? req.targetPrice.toStringAsFixed(0) : '');
    final initQty = req.remainingQuantity > 0 ? req.remainingQuantity : req.requestedQuantity;
    _quantityController = TextEditingController(text: initQty > 0 ? initQty.toStringAsFixed(0) : '');
    _deliveryTermsController = TextEditingController(text: req.deliveryTerms);
    _paymentTermsController = TextEditingController(text: 'CAD against Invoice / Delivery');
    _packagingController = TextEditingController(text: 'Standard 50kg Bags');
    _deliveryLocationController = TextEditingController(text: req.deliveryTerms.isNotEmpty ? req.deliveryTerms : 'Buyer Mandi Warehouse');
    _notesController = TextEditingController();

    _priceBasis = 'ex_mill';
    _deliveryDate = req.targetDate;

    _priceController.addListener(_recomputeValues);
    _quantityController.addListener(_recomputeValues);

    _loadNegotiationDetails();
  }

  @override
  void dispose() {
    _priceController.removeListener(_recomputeValues);
    _quantityController.removeListener(_recomputeValues);
    _priceController.dispose();
    _quantityController.dispose();
    _deliveryTermsController.dispose();
    _paymentTermsController.dispose();
    _packagingController.dispose();
    _deliveryLocationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _recomputeValues() {
    if (mounted) setState(() {});
  }

  Future<void> _loadNegotiationDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repo = ref.read(workRepositoryProvider);
    final result = await repo.getRequirementNegotiationDetails(widget.requirement.id);

    if (!mounted) return;

    switch (result) {
      case WorkSuccess<RequirementNegotiationData>(data: final data):
        setState(() {
          _negotiationData = data;
          _isLoading = false;

          // If there's an active proposal, update controllers
          if (data.activeProposal != null) {
            final active = data.activeProposal!;
            if (active.proposedPrice > 0) {
              _priceController.text = active.proposedPrice.toStringAsFixed(0);
            }
            if (active.proposedQuantity > 0) {
              _quantityController.text = active.proposedQuantity.toStringAsFixed(0);
            }
            if (active.paymentTerms != null && active.paymentTerms!.isNotEmpty) {
              _paymentTermsController.text = active.paymentTerms!;
            }
            if (active.packaging != null && active.packaging!.isNotEmpty) {
              _packagingController.text = active.packaging!;
            }
            if (active.deliveryDate != null) {
              final parsed = DateTime.tryParse(active.deliveryDate!);
              if (parsed != null) _deliveryDate = parsed;
            }
          }
        });
      case WorkError(message: final msg):
        setState(() {
          _errorMessage = msg;
          _isLoading = false;
        });
      case WorkUnauthorized(message: final msg):
        setState(() {
          _errorMessage = msg;
          _isLoading = false;
        });
      case WorkContractPending(contractNotice: final notice):
        setState(() {
          _errorMessage = notice;
          _isLoading = false;
        });
    }
  }

  Future<void> _submitProposal() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final qty = double.tryParse(_quantityController.text.trim()) ?? 0;

    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid offered price greater than 0')),
      );
      return;
    }

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid offered quantity greater than 0')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final repo = ref.read(workRepositoryProvider);
    final result = await repo.submitRequirementProposal(
      requirementId: widget.requirement.id,
      offeredPrice: price,
      quantity: qty,
      deliveryDate: _deliveryDate.toIso8601String().substring(0, 10),
      paymentTerms: _paymentTermsController.text.trim(),
      packaging: _packagingController.text.trim(),
      brokerNotes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      expectedVersionNumber: (_negotiationData?.currentVersionNumber ?? 0) + 1,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    switch (result) {
      case WorkSuccess<RequirementNegotiationData>():
        // Refresh requirements in Work Desk controller
        ref.read(requirementsProvider.notifier).loadRequirements();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Row(
                children: [
                  const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Proposal submitted for ${widget.requirement.ref} at ₹${price.toStringAsFixed(0)}/${widget.requirement.unitSymbol}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
          Navigator.of(context).pop(true);
        }
      case WorkError(message: final msg):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(msg)),
              ],
            ),
          ),
        );
      case WorkUnauthorized(message: final msg):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(msg),
          ),
        );
      case WorkContractPending(contractNotice: final notice):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.info,
            content: Text(notice),
          ),
        );
    }
  }

  Future<void> _pickDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimaryLight,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _deliveryDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final req = widget.requirement;

    final proposedPrice = double.tryParse(_priceController.text.trim()) ?? 0;
    final proposedQty = double.tryParse(_quantityController.text.trim()) ?? 0;
    final totalValue = proposedPrice * proposedQty;
    final priceDiff = req.targetPrice > 0 ? proposedPrice - req.targetPrice : 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.scale, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Negotiate Terms • ${req.ref}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${req.commodityName} (${req.gradeName}) • ${req.buyerCompanyName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondaryLight),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.alertCircle, size: 18, color: AppColors.error),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(fontSize: 12, color: AppColors.error),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _loadNegotiationDetails,
                                    child: const Text('Retry', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          // Target vs Proposed Summary Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Buyer Target Price',
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '₹${req.targetPrice.toStringAsFixed(0)} / ${req.unitSymbol}',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Price Variance',
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          priceDiff == 0
                                              ? 'At Par'
                                              : (priceDiff > 0 ? '+₹${priceDiff.toStringAsFixed(0)}' : '-₹${priceDiff.abs().toStringAsFixed(0)}'),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: priceDiff > 0
                                                ? AppColors.error
                                                : (priceDiff < 0 ? AppColors.success : AppColors.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Contract Volume',
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${proposedQty.toStringAsFixed(0)} / ${req.requestedQuantity.toStringAsFixed(0)} ${req.unitSymbol}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Total Contract Value',
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          currencyFormatter.format(totalValue),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Commercial Inputs
                          const Text(
                            'Commercial Proposal Terms',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),

                          // Price & Quantity Row
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Offered Price (₹/${req.unitSymbol}) *',
                                    prefixText: '₹ ',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Required';
                                    if (double.tryParse(v.trim()) == null) return 'Invalid';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _quantityController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Quantity (${req.unitSymbol}) *',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Required';
                                    if (double.tryParse(v.trim()) == null) return 'Invalid';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Price Basis & Target Date Row
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _priceBasis,
                                  decoration: InputDecoration(
                                    labelText: 'Price Basis',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'ex_mill', child: Text('Ex-Mill')),
                                    DropdownMenuItem(value: 'delivered', child: Text('Delivered / FOR')),
                                    DropdownMenuItem(value: 'fob', child: Text('FOB Mandi')),
                                    DropdownMenuItem(value: 'cif', child: Text('CIF Destination')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _priceBasis = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickDeliveryDate,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Delivery Date',
                                      isDense: true,
                                      suffixIcon: const Icon(LucideIcons.calendar, size: 16),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: Text(
                                      DateFormat('dd MMM yyyy').format(_deliveryDate),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Delivery Location / Mandi
                          TextFormField(
                            controller: _deliveryLocationController,
                            decoration: InputDecoration(
                              labelText: 'Delivery Destination / Mandi',
                              prefixIcon: const Icon(LucideIcons.mapPin, size: 16),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Delivery Terms & Payment Terms
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _deliveryTermsController,
                                  decoration: InputDecoration(
                                    labelText: 'Delivery Terms',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _paymentTermsController,
                                  decoration: InputDecoration(
                                    labelText: 'Payment Terms',
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Packaging
                          TextFormField(
                            controller: _packagingController,
                            decoration: InputDecoration(
                              labelText: 'Packaging Specifications',
                              prefixIcon: const Icon(LucideIcons.package, size: 16),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Notes / Remarks to Buyer
                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Broker Proposal Remarks / Audit Justification',
                              hintText: 'e.g. Counter-offer based on active local mandi arrivals.',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Negotiation Rounds / History Section
                          Row(
                            children: [
                              const Icon(LucideIcons.history, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Negotiation Timeline & History',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                ),
                              ),
                              if (_negotiationData != null && _negotiationData!.rounds.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_negotiationData!.rounds.length} round(s)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (_negotiationData == null || _negotiationData!.rounds.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: const Text(
                                'No previous commercial counter-proposals recorded. Submitting this proposal will initiate Round 1 with the buyer mandate.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                              ),
                            )
                          else
                            ..._negotiationData!.rounds.map((round) => _buildRoundCard(round)),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
          ),

          // Action Button
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.send, size: 18),
              label: Text(
                _isSubmitting
                    ? 'Submitting Commercial Proposal...'
                    : (_negotiationData?.activeProposal != null ? 'Submit Revised Proposal' : 'Initiate Negotiation & Propose'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              onPressed: _isSubmitting ? null : _submitProposal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundCard(NegotiationRoundItem round) {
    final isBroker = round.senderRole == 'broker';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isBroker ? AppColors.primaryContainer.withValues(alpha: 0.15) : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBroker ? AppColors.primary.withValues(alpha: 0.3) : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isBroker ? AppColors.primary : AppColors.textSecondaryLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Round ${round.roundNumber}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        round.senderName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                round.createdAtFormatted,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Offered: ₹${round.proposedPrice.toStringAsFixed(0)} / ${widget.requirement.unitSymbol}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Qty: ${round.proposedQuantity.toStringAsFixed(0)} ${widget.requirement.unitSymbol}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (round.notes != null && round.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Remarks: ${round.notes}',
              style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.textSecondaryLight),
            ),
          ],
        ],
      ),
    );
  }
}
