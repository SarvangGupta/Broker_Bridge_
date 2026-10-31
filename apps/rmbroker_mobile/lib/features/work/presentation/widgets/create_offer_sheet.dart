import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/saved_locations_repository.dart';
import '../../domain/offer_model.dart';
import '../../domain/saved_location_model.dart';
import '../../domain/trade_master_data.dart';
import '../controllers/master_data_controller.dart';
import '../controllers/offers_controller.dart';
import 'change_location_sheet.dart';
import 'product_grade_fields.dart';
import 'trade_form_widgets.dart';

class CreateOfferSheet extends ConsumerStatefulWidget {
  const CreateOfferSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
  String _priceVisibility = 'Confidential';
  String? _readyIn;
  String? _locationError;
  SavedLocation? _selectedLocation;
  bool _isLoadingLocation = false;

  final _quantityController = TextEditingController();
  final _askingPriceController = TextEditingController();
  final _notesController = TextEditingController();

  final DateTime _availableFrom = DateTime.now();
  DateTime? _validUntil;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    _askingPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<MasterDropdownItem> _getSellerList(TradeMasterData master) {
    return master.sellerCompanies;
  }

  Future<void> _loadLocationForSeller(String sellerId) async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });
    try {
      final loc = await ref.read(savedLocationsRepositoryProvider).getDefaultLocation(sellerId);
      // A newer seller selection owns the result.
      if (mounted && _selectedSellerId == sellerId) {
        setState(() {
          _selectedLocation = loc;
          _isLoadingLocation = false;
        });
      }
    } on SavedLocationsUnavailable catch (e) {
      if (mounted && _selectedSellerId == sellerId) {
        setState(() {
          _locationError = e.message;
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _pickValidUntilDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? _availableFrom.add(const Duration(days: 14)),
      firstDate: _availableFrom,
      lastDate: _availableFrom.add(const Duration(days: 180)),
    );
    if (picked != null && mounted) {
      setState(() => _validUntil = picked);
    }
  }

  Future<void> _onSellerChanged(String sellerId, List<MasterDropdownItem> sellers) async {
    setState(() {
      _selectedSellerId = sellerId;
      _selectedLocation = null;
    });
    await _loadLocationForSeller(sellerId);
  }

  Future<void> _openChangeLocation(List<MasterDropdownItem> sellers) async {
    if (_selectedSellerId == null) {
      setState(() => _errorMessage = 'Please select a seller first');
      return;
    }

    final seller = sellers.where((s) => s.id == _selectedSellerId).firstOrNull;
    final picked = await ChangeLocationSheet.show(
      context: context,
      companyId: _selectedSellerId!,
      companyName: seller?.name ?? 'Seller Counterparty',
      currentLocationId: _selectedLocation?.id,
      role: LocationRole.loading,
    );

    if (picked != null && mounted) {
      setState(() => _selectedLocation = picked);
    }
  }

  void _openLabReportDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.flaskConical, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Expanded(child: Text('Commodity Lab Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          ],
        ),
        content: const Text(
          'Lab report upload is not available yet. You can save this offer without one.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (_selectedSellerId == null || _selectedSellerId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a seller');
      return;
    }
    if (_selectedCommodityId == null || _selectedCommodityId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a commodity');
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
      setState(() => _errorMessage = 'Quantity must be greater than zero');
      return;
    }

    final askingPrice = double.tryParse(_askingPriceController.text.trim()) ?? 0;
    if (askingPrice <= 0) {
      setState(() => _errorMessage = 'Price must be greater than zero');
      return;
    }

    final unitId = master.unitIdFor(_selectedUnitSymbol);
    if (unitId == null) {
      setState(() => _errorMessage = 'Unit $_selectedUnitSymbol is not available in the master list');
      return;
    }

    final readyIn = _readyIn;
    if (readyIn == null) {
      setState(() => _errorMessage = 'Please select when the stock is ready');
      return;
    }
    final validUntil = _validUntil;
    if (validUntil == null) {
      setState(() => _errorMessage = 'Please select the valid-until date');
      return;
    }

    final location = _selectedLocation;
    if (location == null) {
      setState(() => _errorMessage = 'Please select a load location');
      return;
    }
    final stateId = master.stateIdFor(location.state);
    final districtId = master.districtIdFor(location.city);
    if (stateId == null || districtId == null) {
      setState(() => _errorMessage = '${location.name} has no valid state or district. Choose another location.');
      return;
    }
    final loadingSnapshot = master.locationSnapshot(
      name: location.name,
      address: location.address,
      city: location.city,
      state: location.state,
    );
    final notes = _notesController.text.trim();

    final dto = CreateOfferDto(
      companyId: _selectedSellerId!,
      commodityId: _selectedCommodityId!,
      gradeId: _selectedGradeId!,
      quantity: qty,
      unitId: unitId,
      askingPrice: askingPrice,
      confidentialMinimumPrice: _priceVisibility == 'Confidential' ? (askingPrice * 0.98).roundToDouble() : null,
      stateId: stateId,
      districtId: districtId,
      availableFrom: _availableFrom,
      validUntil: validUntil,
      loadingStatus: readyIn == 'Immediate' || readyIn.toLowerCase().contains('ready')
          ? LoadingReadiness.readyToLoad
          : LoadingReadiness.notReady,
      loadingRemarks: notes.isEmpty ? loadingSnapshot : '$loadingSnapshot | Notes: $notes',
      locationId: location.id,
      locationSnapshot: loadingSnapshot,
      priceVisibility: _priceVisibility,
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
              content: Text('Seller offer saved successfully on desk'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          setState(() {
            _isSubmitting = false;
            _errorMessage = ref.read(offersProvider.notifier).lastCreateError ??
                'Failed to record seller offer. Please verify inputs.';
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
            _selectedSellerId = null;
            _selectedCommodityId = null;
            _selectedGradeId = null;
            _selectedLocation = null;
          });
        }
      });
    });

    final master = masterAsync.value ?? TradeMasterData.fallback();
    final sellers = _getSellerList(master);

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
                title: 'New Seller Offer',
                subtitle: 'Add available stock to sell',
                icon: LucideIcons.packagePlus,
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
                        title: 'Seller & Product',
                        children: [
                          TradeFormRow(
                            icon: LucideIcons.store,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TradeField(
                              label: 'Seller',
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('seller_counterparty_dropdown_$_selectedSellerId'),
                                isExpanded: true,
                                decoration: tradeInputDecoration(),
                                hint: const Text('Select seller', overflow: TextOverflow.ellipsis),
                                initialValue: _selectedSellerId,
                                items: sellers
                                    .map((s) => DropdownMenuItem<String>(
                                          value: s.id,
                                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) _onSellerChanged(val, sellers);
                                },
                              ),
                                  ),
                                ),
                                TradeViewButton(
                                  onPressed: () => showTradeCounterpartySummary(
                                    context,
                                    sellers.where((s) => s.id == _selectedSellerId).firstOrNull?.name ?? 'No seller selected',
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
                                  child: TradeField(
                                    label: 'Quantity',
                                    child: TextFormField(
                                      key: const Key('offer_quantity_field'),
                                      controller: _quantityController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: tradeInputDecoration(hint: 'Enter quantity'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TradeField(
                                    label: 'Unit',
                                    child: DropdownButtonFormField<String>(
                                      key: const Key('offer_unit_dropdown'),
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
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TradeField(
                                    label: 'Price (₹/$_selectedUnitSymbol)',
                                    child: TextFormField(
                                      key: const Key('offer_price_field'),
                                      controller: _askingPriceController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: tradeInputDecoration(hint: 'Enter price'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TradeField(
                                    label: 'Price visibility',
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      decoration: tradeInputDecoration(),
                                      initialValue: _priceVisibility,
                                      items: const [
                                        DropdownMenuItem<String>(
                                          value: 'Confidential',
                                          child: Text('Confidential', overflow: TextOverflow.ellipsis),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'Visible',
                                          child: Text('Market Visible', overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => _priceVisibility = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      TradeFormSection(
                        number: '3',
                        title: 'Stock & Dispatch (Loading)',
                        children: [
                          TradeFormRow(
                            icon: LucideIcons.truck,
                            topInset: 0,
                            child: _buildLoadFrom(sellers),
                          ),
                          TradeFormRow(
                            icon: LucideIcons.calendar,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TradeField(
                                    label: 'Ready in',
                                    child: DropdownButtonFormField<String>(
                                      key: const Key('offer_ready_dropdown'),
                                      isExpanded: true,
                                      decoration: tradeInputDecoration(),
                                      hint: const Text('Select readiness', overflow: TextOverflow.ellipsis),
                                      initialValue: _readyIn,
                                      items: const [
                                        DropdownMenuItem(value: 'Immediate', child: Text('Immediate / Ready', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'Within 3 Days', child: Text('Within 3 Days', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'Within 7 Days', child: Text('Within 7 Days', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'Within 14 Days', child: Text('Within 14 Days', overflow: TextOverflow.ellipsis)),
                                      ],
                                      onChanged: (val) => setState(() => _readyIn = val),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TradeField(
                                    label: 'Valid until',
                                    child: TradeDateField(
                                      key: const Key('offer_valid_until_field'),
                                      date: _validUntil,
                                      onTap: _pickValidUntilDate,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      TradeFormSection(
                        number: '4',
                        title: 'Additional (Optional)',
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionTile(
                                  key: const Key('offer_lab_report_tile'),
                                  icon: LucideIcons.flaskConical,
                                  title: 'Lab report',
                                  subtitle: 'Upload coming soon',
                                  onTap: _openLabReportDialog,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildActionTile(
                                  key: const Key('offer_notes_tile'),
                                  icon: LucideIcons.fileText,
                                  title: 'Notes',
                                  subtitle: _notesController.text.trim().isEmpty ? 'Optional' : 'Notes added',
                                  onTap: _openNotesDialog,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TradeSaveButton(
                buttonKey: const Key('save_offer_button'),
                label: 'Save Offer',
                savingLabel: 'Saving Offer...',
                isSaving: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadFrom(List<MasterDropdownItem> sellers) {
    final sellerId = _selectedSellerId;
    final location = _selectedLocation;
    final Widget body;
    if (sellerId == null) {
      body = const TradeNoLocationCard(message: 'Select a seller to load their saved locations.');
    } else if (_isLoadingLocation) {
      body = const TradeLoadingRow(message: 'Fetching seller\'s saved location...');
    } else if (_locationError != null) {
      body = TradeNoLocationCard(message: _locationError!, onRetry: () => _loadLocationForSeller(sellerId));
    } else if (location == null) {
      body = TradeNoLocationCard(message: 'This seller has no saved location.', onAdd: () => _openChangeLocation(sellers));
    } else {
      body = TradeSavedLocationCard(
        location: location,
        selectedText: 'Selected from seller\'s saved locations',
        changeKey: const Key('change_loading_location_btn'),
        onChange: () => _openChangeLocation(sellers),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TradeLocationLabel(label: 'Load from', badge: 'From seller\'s saved locations'),
        const SizedBox(height: 6),
        body,
      ],
    );
  }

  Future<void> _openNotesDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          key: const Key('offer_notes_field'),
          controller: _notesController,
          maxLines: 4,
          autofocus: true,
          decoration: tradeInputDecoration(hint: 'Lot remarks, moisture, bagging'),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _buildActionTile({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF2563EB)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.textMutedLight),
          ],
        ),
      ),
    );
  }
}