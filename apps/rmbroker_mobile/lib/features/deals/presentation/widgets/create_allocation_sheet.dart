import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../work/domain/offer_model.dart';
import '../../../work/domain/requirement_model.dart';
import '../../../work/presentation/controllers/offers_controller.dart';
import '../../../work/presentation/controllers/requirements_controller.dart';
import '../../domain/allocation_model.dart';
import '../../domain/deal_model.dart';
import '../controllers/allocations_controller.dart';
import '../controllers/deals_controller.dart';

class CreateAllocationSheet extends ConsumerStatefulWidget {
  final RequirementItem requirement;
  final OfferItem offer;

  const CreateAllocationSheet({
    super.key,
    required this.requirement,
    required this.offer,
  });

  static void show({
    required BuildContext context,
    required RequirementItem requirement,
    required OfferItem offer,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreateAllocationSheet(
        requirement: requirement,
        offer: offer,
      ),
    );
  }

  @override
  ConsumerState<CreateAllocationSheet> createState() => _CreateAllocationSheetState();
}

class _CreateAllocationSheetState extends ConsumerState<CreateAllocationSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _qtyController;
  late final TextEditingController _priceController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;

  String _priceBasis = 'FOR_DESTINATION';
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _showConfirmationSummary = false;

  // Post-submission success state
  AllocationItem? _createdAllocation;
  DealItem? _createdDeal;

  @override
  void initState() {
    super.initState();
    // Default proposed quantity is minimum of remaining requirement and available offer
    final maxEligible = min(widget.requirement.remainingQuantity, widget.offer.availableQuantity);
    _qtyController = TextEditingController(
      text: maxEligible > 0 ? maxEligible.toStringAsFixed(maxEligible.truncateToDouble() == maxEligible ? 0 : 2) : '',
    );
    _priceController = TextEditingController(
      text: widget.offer.askingPrice > 0 ? widget.offer.askingPrice.toInt().toString() : '',
    );
    _locationController = TextEditingController(
      text: widget.requirement.deliveryTerms.isNotEmpty
          ? widget.requirement.deliveryTerms
          : '${widget.offer.districtName}, ${widget.offer.stateName}',
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _proposedQty => double.tryParse(_qtyController.text) ?? 0.0;
  double get _agreedPrice => double.tryParse(_priceController.text) ?? 0.0;
  double get _totalValuation => _proposedQty * _agreedPrice;

  double get _remainingReqQty =>
      max(0.0, widget.requirement.remainingQuantity - _proposedQty);
  double get _remainingOfferQty =>
      max(0.0, widget.offer.availableQuantity - _proposedQty);

  void _onProceedToSummary() {
    if (!_formKey.currentState!.validate()) return;

    if (_proposedQty <= 0) {
      setState(() => _errorMessage = 'Allocation quantity must be greater than zero');
      return;
    }
    if (_proposedQty > widget.requirement.remainingQuantity) {
      setState(() => _errorMessage =
          'Proposed quantity cannot exceed remaining requirement (${widget.requirement.remainingQuantity} MT)');
      return;
    }
    if (_proposedQty > widget.offer.availableQuantity) {
      setState(() => _errorMessage =
          'Proposed quantity cannot exceed offer available quantity (${widget.offer.availableQuantity} MT)');
      return;
    }

    setState(() {
      _errorMessage = null;
      _showConfirmationSummary = true;
    });
  }

  Future<void> _executeAuthoritativeAllocation() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final allocDto = CreateAllocationDto(
      requirementId: widget.requirement.id,
      availabilityId: widget.offer.id,
      proposedQuantity: _proposedQty,
      unitSymbol: widget.requirement.unitSymbol,
      remainingRequirementQuantity: widget.requirement.remainingQuantity,
      availableOfferQuantity: widget.offer.availableQuantity,
      agreedPrice: _agreedPrice,
      priceBasis: _priceBasis,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    // 1. Propose & confirm allocation on authoritative backend
    final allocNotifier = ref.read(allocationsProvider(widget.requirement.id).notifier);
    final allocResult = await allocNotifier.proposeAllocation(allocDto);

    if (allocResult == null) {
      final allocState = ref.read(allocationsProvider(widget.requirement.id));
      setState(() {
        _isSubmitting = false;
        _errorMessage = allocState.errorMessage ?? allocState.contractNotice ?? 'Failed to submit allocation';
      });
      return;
    }

    // 2. Automatically generate initial Draft / Negotiation deal record linking allocation
    final dealDto = CreateDealDto(
      allocationId: allocResult.id,
      agreedPrice: _agreedPrice,
      agreedQuantity: _proposedQty,
      priceBasis: _priceBasis,
      deliveryLocation: _locationController.text.trim(),
      deliveryDate: DateTime.now().add(const Duration(days: 7)),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    final dealResult = await ref.read(dealsProvider.notifier).createDeal(dealDto);

    // 3. Refresh requirement desk and offer desk state to update available quantities
    ref.read(requirementsProvider.notifier).loadRequirements();
    ref.read(offersProvider.notifier).loadOffers();

    setState(() {
      _isSubmitting = false;
      _createdAllocation = allocResult;
      _createdDeal = dealResult;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, max(20.0, bottomPadding + 16)),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Row(
              children: [
                const Icon(LucideIcons.gitCommit, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Allocate Supply to Mandate',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // SUCCESS STATE
            if (_createdAllocation != null) ...[
              _buildSuccessView(currencyFormat),
            ] else if (_showConfirmationSummary) ...[
              _buildConfirmationSummaryView(currencyFormat),
            ] else ...[
              _buildAllocationFormView(currencyFormat),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationFormView(NumberFormat currencyFormat) {
    final maxEligible = min(widget.requirement.remainingQuantity, widget.offer.availableQuantity);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Matched Counterparties Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.requirement.commodityName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.goldMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Intermediary Allocation',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.goldDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Buyer Mandate', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
                          Text(
                            widget.requirement.buyerCompanyName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Rem: ${widget.requirement.formattedRemainingQuantity}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(LucideIcons.arrowRight, size: 16, color: AppColors.textSecondaryLight),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Seller Lot', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
                          Text(
                            widget.offer.sellerCompanyName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Avail: ${widget.offer.formattedAvailableQuantity}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quantity Input & Math
          Row(
            children: [
              const Text(
                'Proposed Allocation Quantity *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'Max Eligible: ${maxEligible.toStringAsFixed(1)} MT',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Enter quantity in MT',
              suffixText: 'MT',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Quantity is required';
              final d = double.tryParse(val);
              if (d == null || d <= 0) return 'Must be greater than 0';
              if (d > widget.requirement.remainingQuantity) {
                return 'Exceeds requirement balance (${widget.requirement.remainingQuantity} MT)';
              }
              if (d > widget.offer.availableQuantity) {
                return 'Exceeds offer availability (${widget.offer.availableQuantity} MT)';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),

          // Live Math Indicators
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Req Balance After:', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
                    Text(
                      '${_remainingReqQty.toStringAsFixed(1)} MT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _remainingReqQty == 0 ? AppColors.success : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Offer Avail After:', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight)),
                    Text(
                      '${_remainingOfferQty.toStringAsFixed(1)} MT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _remainingOfferQty == 0 ? AppColors.success : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Agreed Price & Valuation
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Agreed Price / MT *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Price required';
                        final d = double.tryParse(val);
                        if (d == null || d <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Price Basis', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _priceBasis,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'FOR_DESTINATION', child: Text('FOR Dest')),
                        DropdownMenuItem(value: 'EX_MANDI', child: Text('Ex-Mandi')),
                        DropdownMenuItem(value: 'EX_MILL', child: Text('Ex-Mill')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _priceBasis = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Delivery Location
          const Text('Delivery Location *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(
              hintText: 'e.g. Unjha Mandi, Gujarat',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
            validator: (val) => val == null || val.trim().isEmpty ? 'Location required' : null,
          ),
          const SizedBox(height: 14),

          // Total Contract Valuation Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimated Total Value:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                ),
                Text(
                  currencyFormat.format(_totalValuation),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle, size: 14, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Proceed to Confirmation Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _onProceedToSummary,
              child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Review Allocation Summary',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                SizedBox(width: 6),
                Icon(LucideIcons.arrowRight, size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildConfirmationSummaryView(NumberFormat currencyFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Allocation Confirmation Summary',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildSummaryRow('Commodity & Grade', '${widget.requirement.commodityName} (${widget.offer.gradeName})'),
              _buildSummaryRow('Buyer Enterprise', widget.requirement.buyerCompanyName),
              _buildSummaryRow('Seller Enterprise', widget.offer.sellerCompanyName),
              _buildSummaryRow('Proposed Allocation', '$_proposedQty MT'),
              _buildSummaryRow('Agreed Rate', '${currencyFormat.format(_agreedPrice)} / MT ($_priceBasis)'),
              _buildSummaryRow('Total Contract Value', currencyFormat.format(_totalValuation), isBold: true),
              _buildSummaryRow('Delivery Destination', _locationController.text.trim()),
              _buildSummaryRow('Req Remaining Balance', '${_remainingReqQty.toStringAsFixed(1)} MT'),
              _buildSummaryRow('Offer Remaining Stock', '${_remainingOfferQty.toStringAsFixed(1)} MT'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Compliance notice
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.goldMuted.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(LucideIcons.info, size: 14, color: AppColors.goldDark),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Authoritative submission locks proposed allocation and initiates a Draft/Negotiation deal record. Double-allocations are strictly prevented by backend concurrency locks.',
                  style: TextStyle(fontSize: 10.5, color: AppColors.goldDark, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, size: 14, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.error, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : () => setState(() => _showConfirmationSummary = false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back to Edit'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _executeAuthoritativeAllocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.checkCheck, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Authoritatively Commit',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessView(NumberFormat currencyFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.checkCheck, size: 36, color: AppColors.success),
        ),
        const SizedBox(height: 12),
        const Text(
          'Allocation Committed Successfully!',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
        ),
        const SizedBox(height: 4),
        Text(
          'Allocation Ref: ${_createdAllocation?.reference ?? "ALC-CONFIRMED"}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
        ),
        const SizedBox(height: 14),

        // Result Details Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              _buildSummaryRow('Allocated Quantity', '${_createdAllocation?.formattedQuantity}'),
              _buildSummaryRow('Status', _createdAllocation?.status.displayLabel ?? 'Confirmed'),
              if (_createdDeal != null)
                _buildSummaryRow('Generated Deal Ref', _createdDeal!.ref, isBold: true),
              _buildSummaryRow('Total Valuation', currencyFormat.format(_totalValuation)),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Close Desk'),
              ),
            ),
            if (_createdDeal != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/deals/${_createdDeal!.id}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('View Deal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      SizedBox(width: 4),
                      Icon(LucideIcons.arrowRight, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isBold ? AppColors.primaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
