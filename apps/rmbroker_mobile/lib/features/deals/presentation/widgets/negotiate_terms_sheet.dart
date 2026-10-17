import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/deal_model.dart';
import '../controllers/deal_detail_controller.dart';
import '../controllers/deals_controller.dart';

/// Modal bottom sheet allowing authorized brokers to propose versioned amendments to deal terms.
/// Computes and renders a real-time Visual Diff (Before vs Proposed) before submission.
class NegotiateTermsSheet extends ConsumerStatefulWidget {
  final String dealId;
  final DealDetailItem currentDetail;

  const NegotiateTermsSheet({
    super.key,
    required this.dealId,
    required this.currentDetail,
  });

  static Future<void> show(
    BuildContext context, {
    required String dealId,
    required DealDetailItem currentDetail,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NegotiateTermsSheet(
        dealId: dealId,
        currentDetail: currentDetail,
      ),
    );
  }

  @override
  ConsumerState<NegotiateTermsSheet> createState() => _NegotiateTermsSheetState();
}

class _NegotiateTermsSheetState extends ConsumerState<NegotiateTermsSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _locationController;
  late TextEditingController _deliveryTermsController;
  late TextEditingController _paymentTermsController;
  late TextEditingController _packagingController;
  late TextEditingController _commissionRateController;
  late TextEditingController _reasonController;

  late String _priceBasis;
  late DateTime _deliveryDate;

  List<MaterialDiffItem> _liveDiffs = [];

  @override
  void initState() {
    super.initState();
    final deal = widget.currentDetail.deal;
    final detail = widget.currentDetail;

    _priceController = TextEditingController(text: deal.agreedPrice.toStringAsFixed(0));
    _quantityController = TextEditingController(text: deal.agreedQuantity.toStringAsFixed(0));
    _locationController = TextEditingController(text: deal.deliveryLocation ?? 'Destination Warehouse');
    _deliveryTermsController = TextEditingController(text: detail.deliveryTerms);
    _paymentTermsController = TextEditingController(text: detail.paymentTerms);
    _packagingController = TextEditingController(text: detail.packagingType);
    _commissionRateController = TextEditingController(
      text: detail.brokerCommissionRate.toStringAsFixed(0),
    );
    _reasonController = TextEditingController();

    _priceBasis = deal.priceBasis;
    _deliveryDate = deal.deliveryDate != null
        ? DateTime.tryParse(deal.deliveryDate!) ?? DateTime.now().add(const Duration(days: 7))
        : DateTime.now().add(const Duration(days: 7));

    _priceController.addListener(_recomputeDiffs);
    _quantityController.addListener(_recomputeDiffs);
    _locationController.addListener(_recomputeDiffs);
    _deliveryTermsController.addListener(_recomputeDiffs);
    _paymentTermsController.addListener(_recomputeDiffs);
    _packagingController.addListener(_recomputeDiffs);
    _commissionRateController.addListener(_recomputeDiffs);

    _recomputeDiffs();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _deliveryTermsController.dispose();
    _paymentTermsController.dispose();
    _packagingController.dispose();
    _commissionRateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _recomputeDiffs() {
    final deal = widget.currentDetail.deal;
    final detail = widget.currentDetail;

    final oldSnapshot = {
      'rate': deal.agreedPrice,
      'quantity': deal.agreedQuantity,
      'priceBasis': deal.priceBasis,
      'deliveryLocation': deal.deliveryLocation ?? 'Destination Warehouse',
      'deliveryDate': deal.deliveryDate ?? _deliveryDate.toIso8601String().substring(0, 10),
      'deliveryTerms': detail.deliveryTerms,
      'paymentTerms': detail.paymentTerms,
      'packagingType': detail.packagingType,
      'brokerCommissionRate': detail.brokerCommissionRate,
    };

    final proposedPrice = double.tryParse(_priceController.text.trim()) ?? deal.agreedPrice;
    final proposedQty = double.tryParse(_quantityController.text.trim()) ?? deal.agreedQuantity;
    final proposedComm = double.tryParse(_commissionRateController.text.trim()) ?? detail.brokerCommissionRate;

    final proposedSnapshot = {
      'rate': proposedPrice,
      'quantity': proposedQty,
      'priceBasis': _priceBasis,
      'deliveryLocation': _locationController.text.trim(),
      'deliveryDate': _deliveryDate.toIso8601String().substring(0, 10),
      'deliveryTerms': _deliveryTermsController.text.trim(),
      'paymentTerms': _paymentTermsController.text.trim(),
      'packagingType': _packagingController.text.trim(),
      'brokerCommissionRate': proposedComm,
    };

    final diffs = DealVersionEngine.getMaterialDiffList(oldSnapshot, proposedSnapshot);
    if (mounted) {
      setState(() {
        _liveDiffs = diffs;
      });
    }
  }

  Color _getDiffTypeColor(MaterialDiffType type) {
    switch (type) {
      case MaterialDiffType.increased:
        return AppColors.success;
      case MaterialDiffType.reduced:
        return const Color(0xFFD97706);
      case MaterialDiffType.changed:
      case MaterialDiffType.added:
      case MaterialDiffType.removed:
        return AppColors.primary;
    }
  }

  IconData _getDiffTypeIcon(MaterialDiffType type) {
    switch (type) {
      case MaterialDiffType.increased:
        return LucideIcons.arrowUpRight;
      case MaterialDiffType.reduced:
        return LucideIcons.arrowDownRight;
      case MaterialDiffType.changed:
      case MaterialDiffType.added:
      case MaterialDiffType.removed:
        return LucideIcons.gitCommit;
    }
  }

  Future<void> _submitAmendment() async {
    if (!_formKey.currentState!.validate()) return;

    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amendment reason for audit logging (min 3 chars).'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_liveDiffs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No material changes made. Please modify terms to create a revision.'),
        ),
      );
      return;
    }

    final price = double.parse(_priceController.text.trim());
    final quantity = double.parse(_quantityController.text.trim());
    final commission = double.tryParse(_commissionRateController.text.trim()) ?? 50.0;

    final dto = UpdateDealTermsDto(
      dealId: widget.dealId,
      expectedVersion: widget.currentDetail.confirmations.latestVersionNumber,
      agreedPrice: price,
      agreedQuantity: quantity,
      priceBasis: _priceBasis,
      deliveryLocation: _locationController.text.trim(),
      deliveryDate: _deliveryDate,
      deliveryTerms: _deliveryTermsController.text.trim(),
      paymentTerms: _paymentTermsController.text.trim(),
      packagingType: _packagingController.text.trim(),
      brokerCommissionRate: commission,
      reason: reason,
    );

    final success = await ref
        .read(dealDetailProvider(widget.dealId).notifier)
        .proposeTermsAmendment(dto);

    if (mounted) {
      if (success) {
        ref.read(dealsProvider.notifier).loadDeals();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Terms revised to Version ${dto.expectedVersion + 1}. Counterparty confirmations have been reset.',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        final err = ref.read(dealDetailProvider(widget.dealId)).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Failed to update deal terms.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.currentDetail.deal;
    final nextVersion = widget.currentDetail.confirmations.latestVersionNumber + 1;
    final state = ref.watch(dealDetailProvider(widget.dealId));
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.gitPullRequest, size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Negotiate Deal Terms',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Propose terms amendment from v${deal.latestVersionNumber} to v$nextVersion',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Critical Invariant Notice Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.alertTriangle, size: 16, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'CRITICAL RULE: Material revisions (price, volume, delivery, terms) will immediately increment the version and reset all Buyer/Seller confirmations. Old approvals never carry over.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Live Visual Diff Section
                if (_liveDiffs.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(LucideIcons.sparkles, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Live Visual Diff (${_liveDiffs.length} material changes detected)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      children: _liveDiffs.map((diff) {
                        final color = _getDiffTypeColor(diff.type);
                        final icon = _getDiffTypeIcon(diff.type);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(icon, size: 14, color: color),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  diff.label,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${diff.oldValue ?? "None"}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondaryLight,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(LucideIcons.arrowRight, size: 10, color: AppColors.textSecondaryLight),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${diff.newValue}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Commercial Fields
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Agreed Price (₹/${deal.unitSymbol}) *',
                          hintText: 'e.g. 52000',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final num = double.tryParse(v.trim());
                          if (num == null || num <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Agreed Volume (${deal.unitSymbol}) *',
                          hintText: 'e.g. 100',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final num = double.tryParse(v.trim());
                          if (num == null || num <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Price Basis Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _priceBasis,
                  decoration: const InputDecoration(
                    labelText: 'Price Basis *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'FOR_DESTINATION', child: Text('FOR Destination Mill / Mandi')),
                    DropdownMenuItem(value: 'EX_WAREHOUSE', child: Text('Ex-Warehouse (Buyer pays freight)')),
                    DropdownMenuItem(value: 'FOR_BUYER_WAREHOUSE', child: Text('FOR Buyer Warehouse')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _priceBasis = val);
                      _recomputeDiffs();
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Delivery Location
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Location *',
                    hintText: 'e.g. Indore Processing Mill, Warehouse 4',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Location is required' : null,
                ),
                const SizedBox(height: 12),

                // Delivery Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _deliveryDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setState(() => _deliveryDate = picked);
                      _recomputeDiffs();
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Agreed Delivery Window *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: Icon(LucideIcons.calendar, size: 18),
                    ),
                    child: Text(dateFormat.format(_deliveryDate)),
                  ),
                ),
                const SizedBox(height: 12),

                // Delivery & Payment Terms
                TextFormField(
                  controller: _deliveryTermsController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Terms',
                    hintText: 'e.g. FOR Destination Mandi, Unloading by Buyer',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _paymentTermsController,
                  decoration: const InputDecoration(
                    labelText: 'Payment Terms',
                    hintText: 'e.g. 100% Advance against Lorry Receipt',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _packagingController,
                        decoration: const InputDecoration(
                          labelText: 'Packaging Type',
                          hintText: 'e.g. 50kg HDPE Bags',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _commissionRateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Brokerage (₹/${deal.unitSymbol})',
                          hintText: 'e.g. 50',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Mandatory Amendment Reason
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Mandatory Amendment Reason *',
                    hintText: 'e.g. Buyer counter-offered ₹53,000 due to revised mandi freight rates',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Reason is required for audit logs';
                    if (v.trim().length < 3) return 'Reason must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: state.isSubmitting ? null : _submitAmendment,
                    child: state.isSubmitting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              SizedBox(width: 10),
                              Text('Saving Version...', style: TextStyle(color: Colors.white)),
                            ],
                          )
                        : Text(
                            'Propose Version $nextVersion Terms',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
