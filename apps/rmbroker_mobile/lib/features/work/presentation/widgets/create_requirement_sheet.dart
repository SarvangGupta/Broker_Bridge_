import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/saved_locations_repository.dart';
import '../../domain/requirement_model.dart';
import '../../domain/saved_location_model.dart';
import '../../domain/trade_master_data.dart';
import '../controllers/master_data_controller.dart';
import '../controllers/requirements_controller.dart';
import 'change_location_sheet.dart';
import 'product_grade_fields.dart';
import 'trade_form_widgets.dart';

class CreateRequirementSheet extends ConsumerStatefulWidget {
  const CreateRequirementSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
  String? _locationError;
  SavedLocation? _selectedLocation;
  bool _isLoadingLocation = false;

  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _targetDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<MasterDropdownItem> _getBuyerList(TradeMasterData master) {
    return master.buyerCompanies;
  }

  Future<void> _loadLocationForBuyer(String buyerId) async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });
    try {
      final loc = await ref.read(savedLocationsRepositoryProvider).getDefaultLocation(buyerId);
      // A newer buyer selection owns the result.
      if (mounted && _selectedBuyerId == buyerId) {
        setState(() {
          _selectedLocation = loc;
          _isLoadingLocation = false;
        });
      }
    } on SavedLocationsUnavailable catch (e) {
      if (mounted && _selectedBuyerId == buyerId) {
        setState(() {
          _locationError = e.message;
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null && mounted) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _onBuyerChanged(String buyerId, List<MasterDropdownItem> buyers) async {
    setState(() {
      _selectedBuyerId = buyerId;
      _selectedLocation = null;
    });
    await _loadLocationForBuyer(buyerId);
  }

  Future<void> _openChangeLocation(List<MasterDropdownItem> buyers) async {
    if (_selectedBuyerId == null) {
      setState(() => _errorMessage = 'Please select a buyer first');
      return;
    }

    final buyer = buyers.where((b) => b.id == _selectedBuyerId).firstOrNull;
    final picked = await ChangeLocationSheet.show(
      context: context,
      companyId: _selectedBuyerId!,
      companyName: buyer?.name ?? 'Buyer Counterparty',
      currentLocationId: _selectedLocation?.id,
      role: LocationRole.delivery,
    );

    if (picked != null && mounted) {
      setState(() => _selectedLocation = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (_selectedBuyerId == null || _selectedBuyerId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a buyer');
      return;
    }
    if (_selectedCommodityId == null || _selectedCommodityId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a raw material commodity');
      return;
    }
    final master = ref.read(masterDataProvider).value;
    if (master == null || master.isFallback) {
      setState(() => _errorMessage = 'Live company and product lists are not loaded. Tap Retry, then save.');
      return;
    }
    final commodity = master.commodityById(_selectedCommodityId);
    if (commodity == null) {
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
      setState(() => _errorMessage = 'Price must be a positive number');
      return;
    }

    final unitId = master.unitIdFor(_selectedUnitSymbol);
    if (unitId == null) {
      setState(() => _errorMessage = 'Unit $_selectedUnitSymbol is not available in the master list');
      return;
    }

    final targetDate = _targetDate;
    if (targetDate == null) {
      setState(() => _errorMessage = 'Please select the required-by date');
      return;
    }

    final location = _selectedLocation;
    if (location == null) {
      setState(() => _errorMessage = 'Please select an unload location');
      return;
    }
    final deliverySnapshot = master.locationSnapshot(
      name: location.name,
      address: location.address,
      city: location.city,
      state: location.state,
    );

    final notes = _notesController.text.trim();
    final dto = CreateRequirementDto(
      companyId: _selectedBuyerId!,
      commodityId: _selectedCommodityId!,
      gradeId: _selectedGradeId!,
      quantity: qty,
      unitId: unitId,
      targetPrice: price,
      deliveryTerms: deliverySnapshot,
      targetDate: targetDate,
      notes: notes.isNotEmpty ? notes : null,
      locationId: location.id,
      locationSnapshot: deliverySnapshot,
    );

    final validationErr = dto.validate();
    if (validationErr != null) {
      setState(() => _errorMessage = validationErr);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await ref.read(requirementsProvider.notifier).createRequirement(dto);
      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Buyer requirement saved successfully on broker desk'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          setState(() {
            _isSubmitting = false;
            _errorMessage = ref.read(requirementsProvider.notifier).lastCreateError ??
                'Failed to record mandate. Please verify inputs.';
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

    ref.listen<AsyncValue<TradeMasterData>>(masterDataProvider, (prev, next) {
      next.whenData((master) {
        // Retry succeeded: selections made from the sample lists no longer exist.
        if (mounted && prev?.value?.isFallback == true && !master.isFallback) {
          setState(() {
            _selectedBuyerId = null;
            _selectedCommodityId = null;
            _selectedGradeId = null;
            _selectedLocation = null;
          });
        }
      });
    });

    final master = masterAsync.value ?? TradeMasterData.fallback();
    final buyers = _getBuyerList(master);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      child: Material(
        color: AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 14, bottomInset + 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TradeFormHeader(
                title: 'New Buyer Requirement',
                subtitle: 'Add what the buyer needs',
                icon: LucideIcons.filePlus,
              ),
              const SizedBox(height: 12),
              if (_errorMessage != null) TradeErrorBanner(message: _errorMessage!),
              if (masterAsync.isLoading && masterAsync.value == null)
                const TradeLoadingRow(message: 'Loading product catalogue...'),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TradeFormSection(
                        number: '1',
                        title: 'Buyer & Product',
                        children: [
                          TradeFormRow(
                            icon: LucideIcons.user,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TradeField(
                              label: 'Buyer',
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('buyer_counterparty_dropdown_$_selectedBuyerId'),
                                isExpanded: true,
                                decoration: tradeInputDecoration(),
                                hint: const Text('Select buyer', overflow: TextOverflow.ellipsis),
                                initialValue: _selectedBuyerId,
                                items: buyers
                                    .map((b) => DropdownMenuItem<String>(
                                          value: b.id,
                                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) _onBuyerChanged(val, buyers);
                                },
                              ),
                                  ),
                                ),
                                TradeViewButton(
                                  onPressed: () => showTradeCounterpartySummary(
                                    context,
                                    buyers.where((b) => b.id == _selectedBuyerId).firstOrNull?.name ?? 'No buyer selected',
                                    _selectedLocation,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ProductGradeFields(
                            master: master,
                            commodityId: _selectedCommodityId,
                            gradeId: _selectedGradeId,
                            isLoading: masterAsync.isLoading,
                            onRetry: () => ref.invalidate(masterDataProvider),
                            onCommodityChanged: (c) => setState(() {
                              _selectedCommodityId = c.id;
                              final own = master.gradesFor(c.id);
                              _selectedGradeId = own.isNotEmpty ? own.first.id : null;
                            }),
                            onGradeChanged: (g) => setState(() => _selectedGradeId = g),
                          ),
                        ],
                      ),
                      TradeFormSection(
                        number: '2',
                        title: 'Quantity & Price',
                        children: [
                          TradeFormRow(
                            icon: LucideIcons.package,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TradeField(
                                    label: 'Quantity',
                                    child: TextFormField(
                                      key: const Key('requirement_quantity_field'),
                                      controller: _quantityController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: tradeInputDecoration(hint: 'Enter quantity'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: TradeField(
                                    label: 'Unit',
                                    child: DropdownButtonFormField<String>(
                                      key: const Key('requirement_unit_dropdown'),
                                      isExpanded: true,
                                      decoration: tradeInputDecoration(),
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
                                ),
                              ],
                            ),
                          ),
                          TradeFormRow(
                            icon: LucideIcons.indianRupee,
                            child: TradeField(
                              label: 'Price (₹/$_selectedUnitSymbol)',
                              child: TextFormField(
                                key: const Key('requirement_price_field'),
                                controller: _priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: tradeInputDecoration(hint: 'Enter price'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      TradeFormSection(
                        number: '3',
                        title: 'Delivery (Unloading)',
                        children: [
                          TradeFormRow(
                            icon: LucideIcons.mapPin,
                            topInset: 0,
                            child: _buildUnloadAt(buyers),
                          ),
                          TradeFormRow(
                            icon: LucideIcons.calendar,
                            child: TradeField(
                              label: 'Required by',
                              child: TradeDateField(
                                key: const Key('requirement_date_field'),
                                date: _targetDate,
                                onTap: _pickDate,
                              ),
                            ),
                          ),
                          TradeNotesTile(
                            controller: _notesController,
                            hint: 'Special packing, delivery timing',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TradeSaveButton(
                buttonKey: const Key('save_requirement_button'),
                label: 'Save Requirement',
                savingLabel: 'Saving Requirement...',
                isSaving: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnloadAt(List<MasterDropdownItem> buyers) {
    final buyerId = _selectedBuyerId;
    final location = _selectedLocation;
    final Widget body;
    if (buyerId == null) {
      body = const TradeNoLocationCard(message: 'Select a buyer to load their saved locations.');
    } else if (_isLoadingLocation) {
      body = const TradeLoadingRow(message: 'Fetching buyer\'s saved location...');
    } else if (_locationError != null) {
      body = TradeNoLocationCard(message: _locationError!, onRetry: () => _loadLocationForBuyer(buyerId));
    } else if (location == null) {
      body = TradeNoLocationCard(message: 'This buyer has no saved location.', onAdd: () => _openChangeLocation(buyers));
    } else {
      body = TradeSavedLocationCard(
        location: location,
        selectedText: 'Selected from buyer\'s saved locations',
        changeKey: const Key('change_delivery_location_btn'),
        onChange: () => _openChangeLocation(buyers),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TradeLocationLabel(label: 'Unload at', badge: 'From buyer\'s saved locations'),
        const SizedBox(height: 6),
        body,
      ],
    );
  }
}