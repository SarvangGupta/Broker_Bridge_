import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/requirement_model.dart';
import '../../domain/trade_master_data.dart';
import '../controllers/master_data_controller.dart';
import '../controllers/requirements_controller.dart';
import 'product_grade_fields.dart';

class CreateRequirementSheet extends ConsumerStatefulWidget {
  const CreateRequirementSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CreateRequirementSheet(),
    );
  }

  @override
  ConsumerState<CreateRequirementSheet> createState() => _CreateRequirementSheetState();
}

class _CreateRequirementSheetState extends ConsumerState<CreateRequirementSheet> {
  String? _selectedBuyerId;
  String? _selectedCommodityId;
  String? _selectedGradeId;
  String _selectedUnitSymbol = 'MT';

  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _termsController = TextEditingController(text: 'FOR Destination (Jaipur)');
  final _notesController = TextEditingController();

  DateTime _targetDate = DateTime.now().add(const Duration(days: 7));
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _termsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate.isBefore(now) ? now : _targetDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (_selectedBuyerId == null || _selectedBuyerId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a buyer counterparty');
      return;
    }
    if (_selectedCommodityId == null || _selectedCommodityId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a raw material commodity');
      return;
    }
    final master = ref.read(masterDataProvider).value;
    final commodity = master?.commodityById(_selectedCommodityId);
    if (master == null || commodity == null) {
      setState(() => _errorMessage = 'Please select a product from the catalogue');
      return;
    }
    if (master.gradesFor(commodity.id).isEmpty) {
      setState(() => _errorMessage = noGradeMessage(commodity.name));
      return;
    }
    if (_selectedGradeId == null || _selectedGradeId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a quality grade');
      return;
    }
    if (!master.isValidProductGrade(commodity.id, _selectedGradeId)) {
      setState(() => _errorMessage = 'The selected grade does not belong to ${commodity.name}');
      return;
    }

    final qty = double.tryParse(_quantityController.text.trim()) ?? 0;
    if (qty <= 0) {
      setState(() => _errorMessage = 'Quantity must be a positive number');
      return;
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    if (price <= 0) {
      setState(() => _errorMessage = 'Target price must be a positive number');
      return;
    }

    if (_termsController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Delivery terms are required');
      return;
    }

    final dto = CreateRequirementDto(
      companyId: _selectedBuyerId!,
      commodityId: _selectedCommodityId!,
      gradeId: _selectedGradeId!,
      quantity: qty,
      unitId: '00000000-0000-0000-0000-000000000001',
      targetPrice: price,
      deliveryTerms: _termsController.text.trim(),
      targetDate: _targetDate,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    final validationErr = dto.validate();
    if (validationErr != null) {
      setState(() => _errorMessage = validationErr);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success =
          await ref.read(requirementsProvider.notifier).createRequirement(dto);
      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Buyer mandate created successfully on broker desk'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          setState(() {
            _isSubmitting = false;
            _errorMessage = 'Failed to record mandate. Please verify inputs.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterAsync = ref.watch(masterDataProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.filePlus, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Buyer Purchase Mandate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        'Record buyer commodity requirement on broker desk',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
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
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
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
                        style: const TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),

            // Dropdown Options
            masterAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => const Text(
                'Notice: Master data loading fallback active.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
              ),
              data: (master) {
                // Pre-populate dropdown defaults if empty
                final buyers = master.buyerCompanies.isNotEmpty
                    ? master.buyerCompanies
                    : [
                        const MasterDropdownItem(
                            id: '00000000-0000-0000-0000-000000000001',
                            name: 'AgrInnovate Flour Mills'),
                        const MasterDropdownItem(
                            id: '00000000-0000-0000-0000-000000000002',
                            name: 'North Dairy Feed Corp'),
                      ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Buyer Selector
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Buyer Counterparty *',
                        prefixIcon: Icon(LucideIcons.building, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      initialValue: _selectedBuyerId,
                      items: buyers.map((b) {
                        return DropdownMenuItem<String>(value: b.id, child: Text(b.name));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedBuyerId = val),
                    ),
                    const SizedBox(height: 12),

                    // Product (searchable, with category label) & product-specific Grade
                    ProductGradeFields(
                      master: master,
                      commodityId: _selectedCommodityId,
                      gradeId: _selectedGradeId,
                      onRetry: () => ref.invalidate(masterDataProvider),
                      onCommodityChanged: (c) => setState(() {
                        _selectedCommodityId = c.id;
                        final own = master.gradesFor(c.id);
                        _selectedGradeId = own.isNotEmpty ? own.first.id : null;
                      }),
                      onGradeChanged: (g) => setState(() => _selectedGradeId = g),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Quantity & Unit
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Requested Quantity *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Unit *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    initialValue: _selectedUnitSymbol,
                    items: const [
                      DropdownMenuItem<String>(value: 'MT', child: Text('MT')),
                      DropdownMenuItem<String>(value: 'Qtl', child: Text('Quintal')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedUnitSymbol = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Target Price & Delivery Date
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Target Price (₹/$_selectedUnitSymbol) *',
                      prefixText: '₹ ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                        side: const BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                    icon: const Icon(LucideIcons.calendar, size: 16),
                    label: Text(
                      '${_targetDate.day}/${_targetDate.month}/${_targetDate.year}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _pickDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Delivery Terms
            TextFormField(
              controller: _termsController,
              decoration: const InputDecoration(
                labelText: 'Delivery Terms & Destination Mandi *',
                prefixIcon: Icon(LucideIcons.mapPin, size: 18),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Special Specs or Notes (Optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.check, size: 18),
                label: Text(
                  _isSubmitting ? 'Recording Mandate...' : 'Record Buyer Mandate',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                onPressed: _isSubmitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
