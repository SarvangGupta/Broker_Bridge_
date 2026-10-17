import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/offer_model.dart';
import '../../domain/trade_master_data.dart';
import '../controllers/master_data_controller.dart';
import '../controllers/offers_controller.dart';

class CreateOfferSheet extends ConsumerStatefulWidget {
  const CreateOfferSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CreateOfferSheet(),
    );
  }

  @override
  ConsumerState<CreateOfferSheet> createState() => _CreateOfferSheetState();
}

class _CreateOfferSheetState extends ConsumerState<CreateOfferSheet> {
  String? _selectedSellerId;
  String? _selectedCommodityId;
  String? _selectedGradeId;
  String _selectedUnitSymbol = 'MT';
  LoadingReadiness _selectedLoading = LoadingReadiness.notReady;

  final _quantityController = TextEditingController();
  final _askingPriceController = TextEditingController();
  final _floorPriceController = TextEditingController();
  final _mandiController = TextEditingController(text: 'Jaipur Mandi');
  final _stateController = TextEditingController(text: 'Rajasthan');
  final _loadingRemarksController = TextEditingController();

  final DateTime _availableFrom = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 14));
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    _askingPriceController.dispose();
    _floorPriceController.dispose();
    _mandiController.dispose();
    _stateController.dispose();
    _loadingRemarksController.dispose();
    super.dispose();
  }

  Future<void> _pickValidUntilDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: _availableFrom,
      lastDate: _availableFrom.add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() => _validUntil = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (_selectedSellerId == null || _selectedSellerId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a seller counterparty');
      return;
    }
    if (_selectedCommodityId == null || _selectedCommodityId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a commodity');
      return;
    }
    if (_selectedGradeId == null || _selectedGradeId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a quality grade');
      return;
    }

    final qty = double.tryParse(_quantityController.text.trim()) ?? 0;
    if (qty <= 0) {
      setState(() => _errorMessage = 'Offered quantity must be positive');
      return;
    }

    final askingPrice = double.tryParse(_askingPriceController.text.trim()) ?? 0;
    if (askingPrice <= 0) {
      setState(() => _errorMessage = 'Asking price must be positive');
      return;
    }

    double? floorPrice;
    if (_floorPriceController.text.trim().isNotEmpty) {
      floorPrice = double.tryParse(_floorPriceController.text.trim());
      if (floorPrice != null && floorPrice <= 0) {
        setState(() => _errorMessage = 'Confidential floor price must be positive');
        return;
      }
      if (floorPrice != null && floorPrice > askingPrice) {
        setState(() => _errorMessage = 'Confidential floor cannot exceed asking price');
        return;
      }
    }

    final dto = CreateOfferDto(
      companyId: _selectedSellerId!,
      commodityId: _selectedCommodityId!,
      gradeId: _selectedGradeId!,
      quantity: qty,
      unitId: '00000000-0000-0000-0000-000000000001',
      askingPrice: askingPrice,
      confidentialMinimumPrice: floorPrice,
      stateId: '00000000-0000-0000-0000-000000000001',
      districtId: '00000000-0000-0000-0000-000000000002',
      availableFrom: _availableFrom,
      validUntil: _validUntil,
      loadingStatus: _selectedLoading,
      loadingRemarks: _loadingRemarksController.text.trim().isNotEmpty
          ? _loadingRemarksController.text.trim()
          : null,
    );

    final validationErr = dto.validate();
    if (validationErr != null) {
      setState(() => _errorMessage = validationErr);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await ref.read(offersProvider.notifier).createOffer(dto);
      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seller supply lot recorded successfully on desk'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          setState(() {
            _isSubmitting = false;
            _errorMessage = 'Failed to record seller offer. Please verify inputs.';
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
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.packagePlus, size: 20, color: AppColors.success),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Seller Commodity Offer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        'Record seller physical stock lot for matching',
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const SizedBox.shrink(),
              data: (master) {
                final sellers = master.sellerCompanies.isNotEmpty
                    ? master.sellerCompanies
                    : [
                        const MasterDropdownItem(
                            id: '00000000-0000-0000-0000-000000000010',
                            name: 'Apex Cattle Nutrition'),
                        const MasterDropdownItem(
                            id: '00000000-0000-0000-0000-000000000011',
                            name: 'Karnal Agro Traders'),
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
                      ];
                final grades = master.grades.isNotEmpty
                    ? master.grades
                    : [
                        const MasterDropdownItem(
                            id: 'grade-101', name: 'Grade A Milling'),
                        const MasterDropdownItem(
                            id: 'grade-102', name: 'Feed Grade Premium'),
                      ];

                return Column(
                  children: [
                    // Seller Selector
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Seller Counterparty *',
                        prefixIcon: Icon(LucideIcons.store, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      initialValue: _selectedSellerId,
                      items: sellers.map((s) {
                        return DropdownMenuItem<String>(value: s.id, child: Text(s.name));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedSellerId = val),
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
                      labelText: 'Available Lot Quantity *',
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

            // Asking Price & Confidential Floor Price
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _askingPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Asking Price (₹/$_selectedUnitSymbol) *',
                      prefixText: '₹ ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _floorPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Confidential Floor (₹)',
                      prefixIcon: Icon(LucideIcons.lock, size: 14),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Loading Status & Validity Expiry
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<LoadingReadiness>(
                    decoration: const InputDecoration(
                      labelText: 'Loading Readiness',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    initialValue: _selectedLoading,
                    items: LoadingReadiness.values.map((l) {
                      return DropdownMenuItem<LoadingReadiness>(value: l, child: Text(l.displayLabel));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedLoading = val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                        side: const BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                    icon: const Icon(LucideIcons.calendar, size: 15),
                    label: Text(
                      'Valid: ${_validUntil.day}/${_validUntil.month}/${_validUntil.year}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _pickValidUntilDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _mandiController,
                    decoration: const InputDecoration(
                      labelText: 'Mandi / District *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'State *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Lab Report Policy Notice
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.flaskConical, size: 16, color: AppColors.textSecondaryLight),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lab report is optional. Uploaded test documents remain seller-declared and are not independently certified by the platform.',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondaryLight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
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
                  _isSubmitting ? 'Recording Supply Lot...' : 'Record Seller Supply Lot',
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
