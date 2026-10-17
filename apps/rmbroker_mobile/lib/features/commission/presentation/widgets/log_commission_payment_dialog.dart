import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/commission_calculator.dart';
import '../../domain/commission_model.dart';
import '../controllers/commission_controller.dart';

/// Modal dialog for recording a manual or external commission settlement payment.
class LogCommissionPaymentDialog extends ConsumerStatefulWidget {
  final CommissionRecord record;

  const LogCommissionPaymentDialog({
    super.key,
    required this.record,
  });

  static Future<bool?> show(BuildContext context, {required CommissionRecord record}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LogCommissionPaymentDialog(record: record),
    );
  }

  @override
  ConsumerState<LogCommissionPaymentDialog> createState() => _LogCommissionPaymentDialogState();
}

class _LogCommissionPaymentDialogState extends ConsumerState<LogCommissionPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _referenceController;
  late TextEditingController _notesController;
  DateTime _paymentDate = DateTime.now();
  String _direction = 'Buyer to Broker';
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final remaining = widget.record.outstandingAmount > 0
        ? widget.record.outstandingAmount
        : widget.record.eligibleCommission;
    _amountController = TextEditingController(text: remaining > 0 ? remaining.toStringAsFixed(2) : '');
    _referenceController = TextEditingController();
    _notesController = TextEditingController(text: 'Manually recorded by Broker Desk');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _fillRemaining() {
    setState(() {
      _amountController.text = widget.record.outstandingAmount.toStringAsFixed(2);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amt <= 0) {
      setState(() => _errorMessage = 'Payment amount must be greater than zero.');
      return;
    }

    final dto = LogPaymentDto(
      dealId: widget.record.dealId,
      bookingReference: widget.record.bookingReference,
      amount: amt,
      referenceNumber: _referenceController.text.trim(),
      paymentDate: _paymentDate,
      direction: _direction,
      notes: _notesController.text.trim(),
    );

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final success = await ref.read(commissionControllerProvider.notifier).logCommissionPayment(dto);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        final err = ref.read(commissionControllerProvider).errorMessage;
        setState(() => _errorMessage = err ?? 'Failed to log commission payment.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.receipt, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Log Commission Payment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            '${widget.record.dealReference} • ${widget.record.commodityName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Outstanding Balance Card with Quick Fill
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Outstanding Balance',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CommissionCalculator.formatCurrency(widget.record.outstandingAmount),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    if (widget.record.outstandingAmount > 0)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: _fillRemaining,
                        icon: const Icon(LucideIcons.cornerDownLeft, size: 14, color: AppColors.primary),
                        label: const Text(
                          'Fill Balance',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
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
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.alertCircle, size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Received Amount (₹)*',
                  prefixIcon: Icon(LucideIcons.indianRupee, size: 18),
                  hintText: 'e.g. 5000.00',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter amount';
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0) return 'Enter a valid positive amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Reference / UTR Field
              TextFormField(
                controller: _referenceController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Bank Reference / UTR Number*',
                  prefixIcon: Icon(LucideIcons.hash, size: 18),
                  hintText: 'e.g. UTR-HDFC-99482103',
                  helperText: 'Unique banking settlement identifier',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Reference / UTR number is required';
                  if (val.trim().length < 4) return 'Reference must be at least 4 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Payment Direction / Mode
              DropdownButtonFormField<String>(
                initialValue: _direction,
                decoration: const InputDecoration(
                  labelText: 'Settlement Direction*',
                  prefixIcon: Icon(LucideIcons.arrowRightLeft, size: 18),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Buyer to Broker',
                    child: Text('Buyer to Broker (Commission Payout)'),
                  ),
                  DropdownMenuItem(
                    value: 'Seller to Broker',
                    child: Text('Seller to Broker (Commission Deduction)'),
                  ),
                  DropdownMenuItem(
                    value: 'Direct Mandi Settlement',
                    child: Text('Direct Mandi Escrow Settlement'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _direction = val);
                },
              ),
              const SizedBox(height: 12),

              // Payment Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _paymentDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    setState(() => _paymentDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.calendar, size: 18, color: AppColors.textSecondaryLight),
                          const SizedBox(width: 10),
                          Text(
                            'Payment Date: ${dateFormat.format(_paymentDate)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondaryLight),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Remarks / Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Verification Notes',
                  prefixIcon: Icon(LucideIcons.fileText, size: 18),
                  hintText: 'e.g. Bank statement verified on HDFC Jaipur Portal',
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              AppButton(
                label: 'Save & Reconcile Payment',
                icon: const Icon(LucideIcons.checkCheck, size: 18, color: Colors.white),
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Record is auditable. Will immediately update remaining balance.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
