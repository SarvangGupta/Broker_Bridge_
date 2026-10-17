import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/requirement_model.dart';
import '../../domain/trade_master_data.dart';
import '../controllers/master_data_controller.dart';
import '../controllers/requirements_controller.dart';

class CreateRequirementSheet extends ConsumerStatefulWidget {
  const CreateRequirementSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
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
    if (_selectedGradeId == null || _selectedGradeId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a quality grade');
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
                final commodities = master.commodities.isNotEmpty
                    ? master.commodities
                    : [
                        const MasterDropdownItem(
                            id: 'comm-101', name: 'Sharbati Wheat'),
                        const MasterDropdownItem(
                            id: 'comm-102', name: 'Yellow Maize (Corn)'),
                        const MasterDropdownItem(
                            id: 'comm-103', name: 'Soybean Meal (DOC)'),
                        const MasterDropdownItem(
                            id: 'comm-104', name: 'Mustard Seed'),
                      ];
                final grades = master.grades.isNotEmpty
                    ? master.grades
                    : [
                        const MasterDropdownItem(
                            id: 'grade-101', name: 'Grade A Milling'),
                        const MasterDropdownItem(
                            id: 'grade-102', name: 'Feed Grade Premium'),
                        const MasterDropdownItem(
                            id: 'grade-103', name: 'Standard Mandi Grade'),
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

                    // Commodity & Grade
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Commodity *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            initialValue: _selectedCommodityId,
                            items: commodities.map((c) {
                              return DropdownMenuItem<String>(value: c.id, child: Text(c.name));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedCommodityId = val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Quality Grade *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            initialValue: _selectedGradeId,
                            items: grades.map((g) {
                              return DropdownMenuItem<String>(value: g.id, child: Text(g.name));
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedGradeId = val),
                          ),
                        ),
                      ],
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
