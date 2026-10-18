import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/core/widgets/app_button.dart';
import 'package:rmbroker_mobile/core/widgets/app_card.dart';
import 'package:rmbroker_mobile/features/commission/domain/commission_calculator.dart';
import 'package:rmbroker_mobile/features/commission/domain/commission_model.dart';
import 'package:rmbroker_mobile/features/invoices/presentation/controllers/invoice_controller.dart';
import 'package:rmbroker_mobile/features/invoices/domain/invoice_model.dart';

/// Modal bottom sheet allowing an authorized broker to issue a commission invoice
/// from an eligible delivered commission record.
class CreateInvoiceSheet extends ConsumerStatefulWidget {
  final CommissionRecord record;

  const CreateInvoiceSheet({
    super.key,
    required this.record,
  });

  static Future<CommissionInvoice?> show(
    BuildContext context, {
    required CommissionRecord record,
  }) {
    return showModalBottomSheet<CommissionInvoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreateInvoiceSheet(record: record),
    );
  }

  @override
  ConsumerState<CreateInvoiceSheet> createState() => _CreateInvoiceSheetState();
}

class _CreateInvoiceSheetState extends ConsumerState<CreateInvoiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _dateFormat = DateFormat('dd MMM yyyy');

  late String _billedToParty;
  late DateTime _dueDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _billedToParty = 'Buyer Enterprise';
    _dueDate = DateTime.now().add(const Duration(days: 15));
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    final record = widget.record;
    final eligibleQty = record.quantities.eligibleDeliveredQuantity;

    if (eligibleQty <= 0) {
      setState(() {
        _errorMessage =
            'Cannot generate invoice: Delivered & accepted quantity is 0 MT. Deliveries must be accepted before invoicing.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final dto = CreateInvoiceDto(
      dealId: record.dealId,
      dealReference: record.dealReference,
      bookingReference: record.bookingReference ?? '',
      commissionRecordId: record.dealId,
      billedToParty: _billedToParty,
      buyerCompanyName: record.buyerCompanyName,
      sellerCompanyName: record.sellerCompanyName,
      commodityName: record.commodityName,
      gradeName: record.gradeName ?? 'Standard Grade',
      eligibleDeliveredQuantity: eligibleQty,
      agreedRatePerMT: record.agreedRatePerMT,
      calculationBasis: record.commissionBasis,
      dueDate: _dueDate,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    final created = await ref.read(invoiceControllerProvider.notifier).createInvoice(dto);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (created != null) {
      Navigator.pop(context, created);
    } else {
      final state = ref.read(invoiceControllerProvider);
      setState(() {
        _errorMessage = state.errorMessage ?? 'Failed to generate invoice';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final eligibleQty = record.quantities.eligibleDeliveredQuantity;
    final totalAmount = eligibleQty * record.agreedRatePerMT;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
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
              const SizedBox(height: 16),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.fileSpreadsheet, size: 20, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Generate Commission Invoice',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryLight,
                        ),
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

              // Deal Summary Card
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          record.dealReference,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          record.commodityName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Accepted Delivered Quantity:',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                        Text(
                          '${eligibleQty.toStringAsFixed(1)} MT',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Agreed Commission Rate:',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                        Text(
                          '₹${record.agreedRatePerMT.toStringAsFixed(0)} / ${record.commissionBasis}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Invoice Subtotal Due:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          CommissionCalculator.formatCurrency(totalAmount),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Error Banner (e.g. Duplicate Prevention)
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
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Billed-to Selector
              const Text(
                'Party to Bill *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _billedToParty,
                decoration: const InputDecoration(
                  prefixIcon: Icon(LucideIcons.building, size: 16),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Buyer Enterprise',
                    child: Text('Buyer (${record.buyerCompanyName})'),
                  ),
                  DropdownMenuItem(
                    value: 'Seller Enterprise',
                    child: Text('Seller (${record.sellerCompanyName})'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _billedToParty = val);
                },
              ),
              const SizedBox(height: 12),

              // Due Date Selector
              const Text(
                'Payment Due Date *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _selectDueDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.calendar, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            _dateFormat.format(_dueDate),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Notes field
              const Text(
                'Invoice Remarks / Instructions (Optional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g., Payment due via RTGS/NEFT within 15 days of lot acceptance.',
                ),
              ),
              const SizedBox(height: 14),

              // Statutory Notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(LucideIcons.shieldAlert, size: 14, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Brokerage invoice represents intermediary services only. Raw-material payments are settled directly between buyer and seller.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'Issue Invoice',
                      isLoading: _isSubmitting,
                      onPressed: _submitInvoice,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
