import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../search/data/search_repository.dart';
import '../../search/domain/broker_model.dart';
import '../data/requirements_repository.dart';
import '../domain/master_requirement_data.dart';
import '../domain/requirement_model.dart';
import 'commodity_picker_sheet.dart';

/// Screen allowing authenticated buyers to draft, configure commercial preferences,
/// and submit authoritative commodity procurement requirements to the shared backend.
class PostRequirementScreen extends StatefulWidget {
  final String? initialCommodity;
  final String? initialBrokerId;
  final String? initialBrokerName;
  final RequirementsRepository? repository;

  /// When true, quantity, price, delivery location, delivery date and payment
  /// terms start empty for the buyer to enter (used by the Nutrition Guide).
  final bool blankCommercialTerms;

  const PostRequirementScreen({
    super.key,
    this.initialCommodity,
    this.initialBrokerId,
    this.initialBrokerName,
    this.repository,
    this.blankCommercialTerms = false,
  });

  /// Resolves a commodity passed in by route (search result, broker desk, etc.)
  /// against the live catalogue. Returns null when nothing matches, or when a
  /// partial match is ambiguous (e.g. "Maize" → Yellow Maize, Maize DDGS, …),
  /// so an unintended product is never preselected.
  static MasterCommodity? matchInitialCommodity(
    List<MasterCommodity> catalogue,
    String? requested,
  ) {
    final query = requested?.trim().toLowerCase() ?? '';
    if (query.isEmpty) return null;
    for (final c in catalogue) {
      if (c.name.toLowerCase() == query) return c;
    }
    final partial = catalogue.where((c) {
      final name = c.name.toLowerCase();
      return name.contains(query) || query.contains(name);
    }).toList();
    return partial.length == 1 ? partial.single : null;
  }

  @override
  State<PostRequirementScreen> createState() => _PostRequirementScreenState();
}

class _PostRequirementScreenState extends State<PostRequirementScreen> {
  late final RequirementsRepository _repo;

  // Master Data State
  List<MasterCommodity> _commodities = [];
  bool _isLoadingCommodities = true;
  String? _commodityLoadError;
  bool _initialCommodityResolved = false;
  String? _unmatchedInitialCommodity;
  List<MasterGrade> _grades = [];
  bool _isLoadingGrades = false;
  String? _gradeLoadError;
  List<MasterUnit> _units = [];
  List<String> _savedLocations = [];
  List<String> _paymentOptions = [];
  bool _isLoadingMasterData = true;

  // Selected Form Values
  MasterCommodity? _selectedCommodity;
  MasterGrade? _selectedGrade;
  MasterUnit? _selectedUnit;
  String _selectedLocation = '';
  bool _isCustomLocation = false;
  String? _selectedPaymentTerm = 'Payment on Delivery (CAD)';
  String _visibility = 'global'; // 'global' or 'restricted'

  // Broker Selection State (RB-BUYER-07)
  final SearchRepository _searchRepo = SearchRepository();
  List<BrokerModel> _availableBrokers = [];
  final Set<String> _selectedBrokerIds = {};
  final Map<String, String> _selectedBrokerNames = {};
  final _brokerSearchController = TextEditingController();
  bool _isLoadingBrokers = false;
  bool _filterBySelectedCommodity = false;
  String? _brokerSearchError;

  // Controllers
  final _quantityController = TextEditingController(text: '50');
  final _priceController = TextEditingController(text: '4800');
  final _customLocationController = TextEditingController();
  final _packagingController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _targetDate = DateTime.now().add(const Duration(days: 14));
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RequirementsRepository();
    if (widget.blankCommercialTerms) {
      _quantityController.clear();
      _priceController.clear();
      _selectedPaymentTerm = null;
      _targetDate = null;
    }
    _visibility = widget.initialBrokerId != null ? 'restricted' : 'global';

    // Pre-select initial broker desk if routed from broker screen
    if (widget.initialBrokerId != null && widget.initialBrokerId!.isNotEmpty) {
      _selectedBrokerIds.add(widget.initialBrokerId!);
      _selectedBrokerNames[widget.initialBrokerId!] =
          widget.initialBrokerName ?? 'Assigned Broker Desk';
    }

    _loadMasterData();
    _loadCommodities();
    _loadBrokers();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _customLocationController.dispose();
    _packagingController.dispose();
    _notesController.dispose();
    _brokerSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadBrokers() async {
    setState(() {
      _isLoadingBrokers = true;
      _brokerSearchError = null;
    });

    try {
      final commodityFilter =
          _filterBySelectedCommodity ? _selectedCommodity?.name : null;
      final brokers = await _searchRepo.searchBrokers(
        query: _brokerSearchController.text,
        commodityFilter: commodityFilter,
      );

      if (!mounted) return;
      setState(() {
        _availableBrokers = brokers;
        _isLoadingBrokers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBrokers = false;
        _brokerSearchError = 'Failed to load brokers. Tap to retry.';
      });
    }
  }

  void _toggleBrokerSelection(BrokerModel broker) {
    setState(() {
      if (_selectedBrokerIds.contains(broker.id)) {
        _selectedBrokerIds.remove(broker.id);
        _selectedBrokerNames.remove(broker.id);
      } else {
        _selectedBrokerIds.add(broker.id);
        _selectedBrokerNames[broker.id] = broker.name;
      }
    });
  }

  Future<void> _loadMasterData() async {
    try {
      final units = await _repo.getMasterUnits();
      final locations = await _repo.getSavedDeliveryLocations();
      final payments = await _repo.getPaymentTermsOptions();

      if (!mounted) return;

      setState(() {
        _units = units;
        _savedLocations = locations;
        _paymentOptions = payments;
        _selectedUnit = units.isNotEmpty ? units.first : null;
        if (!widget.blankCommercialTerms) {
          _selectedLocation = locations.isNotEmpty ? locations.first : 'FOR Mill Delivery';
          _selectedPaymentTerm = payments.isNotEmpty ? payments.first : 'Payment on Delivery (CAD)';
        }
        _isLoadingMasterData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMasterData = false;
        _errorMessage = 'Failed to load master configuration. Using offline defaults.';
      });
    }
  }

  /// Loads the active catalogue from the shared Product Master. No commodity is
  /// preselected unless the caller passed one that matches the live catalogue.
  Future<void> _loadCommodities() async {
    try {
      final comms = await _repo.getMasterCommodities();
      if (!mounted) return;

      _applyCatalogue(comms);

      if (!_initialCommodityResolved) {
        _initialCommodityResolved = true;
        final requested = widget.initialCommodity?.trim() ?? '';
        final match = PostRequirementScreen.matchInitialCommodity(comms, requested);
        if (match != null) {
          await _onCommodityChanged(match);
        } else if (requested.isNotEmpty && mounted) {
          setState(() => _unmatchedInitialCommodity = requested);
        }
      }
    } catch (e) {
      debugPrint('Commodity catalogue load failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingCommodities = false;
        _commodityLoadError =
            'Could not load the commodity catalogue. Check your connection and retry.';
      });
    }
  }

  void _retryCommodities() {
    setState(() {
      _isLoadingCommodities = true;
      _commodityLoadError = null;
    });
    _loadCommodities();
  }

  /// Refresh used by the picker sheet; rethrows so the sheet can show the failure.
  Future<List<MasterCommodity>> _refreshCatalogue() async {
    final comms = await _repo.getMasterCommodities();
    if (mounted) _applyCatalogue(comms);
    return comms;
  }

  void _applyCatalogue(List<MasterCommodity> comms) {
    setState(() {
      _commodities = comms;
      _isLoadingCommodities = false;
      _commodityLoadError = null;
      // A product deactivated since it was selected must not be submitted.
      final selectedId = _selectedCommodity?.id;
      if (selectedId != null && !comms.any((c) => c.id == selectedId)) {
        _selectedCommodity = null;
        _grades = [];
        _selectedGrade = null;
      }
    });
  }

  Future<void> _openCommodityPicker() async {
    final picked = await showCommodityPickerSheet(
      context: context,
      commodities: _commodities,
      onRefresh: _refreshCatalogue,
      selectedId: _selectedCommodity?.id,
    );
    if (picked != null && mounted) {
      await _onCommodityChanged(picked);
    }
  }

  Future<void> _onCommodityChanged(MasterCommodity? newCommodity) async {
    if (newCommodity == null) return;
    // Clear grades first so a grade from the previous commodity can never be submitted.
    setState(() {
      _selectedCommodity = newCommodity;
      _unmatchedInitialCommodity = null;
      _grades = [];
      _selectedGrade = null;
      _isLoadingGrades = true;
      _gradeLoadError = null;
    });

    try {
      final grades = await _repo.getMasterGrades(newCommodity.id);
      if (!mounted || _selectedCommodity?.id != newCommodity.id) return;
      setState(() {
        _grades = grades;
        _selectedGrade = grades.isNotEmpty ? grades.first : null;
        _isLoadingGrades = false;
      });
    } catch (e) {
      debugPrint('Grade load failed for ${newCommodity.id}: $e');
      if (!mounted || _selectedCommodity?.id != newCommodity.id) return;
      setState(() {
        _isLoadingGrades = false;
        _gradeLoadError = 'Could not load grades for ${newCommodity.name}.';
      });
    }
  }

  String _noGradeMessage(String productName) =>
      'No grade is defined for $productName in the Product Master yet. '
      'It cannot be submitted until a grade is added.';

  Future<void> _handlePost() async {
    if (_isSubmitting) return;

    setState(() {
      _errorMessage = null;
    });

    if (_selectedCommodity == null) {
      setState(() => _errorMessage = 'Please select a commodity.');
      return;
    }

    final grade = _selectedGrade;
    if (grade == null && !_isLoadingGrades && _gradeLoadError == null && _grades.isEmpty) {
      setState(() => _errorMessage = _noGradeMessage(_selectedCommodity!.name));
      return;
    }
    if (grade == null || grade.commodityId != _selectedCommodity!.id) {
      setState(() => _errorMessage =
          'Please select a quality grade for ${_selectedCommodity!.name}.');
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      setState(() => _errorMessage = 'Please enter a valid positive quantity.');
      return;
    }

    // A blank form must not turn an empty price into an implied ₹0 target.
    if (widget.blankCommercialTerms && _priceController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your target price.');
      return;
    }
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    if (price < 0) {
      setState(() => _errorMessage = 'Target price cannot be negative.');
      return;
    }

    final deliveryLoc = _isCustomLocation
        ? _customLocationController.text.trim()
        : _selectedLocation;

    if (deliveryLoc.isEmpty) {
      setState(() => _errorMessage = 'Please specify the delivery location.');
      return;
    }

    final targetDate = _targetDate;
    if (targetDate == null) {
      setState(() => _errorMessage = 'Please select the required delivery date.');
      return;
    }

    final paymentTerm = _selectedPaymentTerm;
    if (paymentTerm == null) {
      setState(() => _errorMessage = 'Please select payment terms.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final selectedIds = _selectedBrokerIds.toList();
    final selectedNames =
        selectedIds.map((id) => _selectedBrokerNames[id] ?? 'Broker Desk').toList();

    final dto = CreateRequirementDto(
      commodityId: _selectedCommodity!.id,
      commodityName: _selectedCommodity!.name,
      gradeId: grade.id,
      gradeName: grade.gradeName,
      quantity: quantity,
      unitId: _selectedUnit?.id ?? '22000000-0000-0000-0000-000000000001',
      unitSymbol: _selectedUnit?.symbol ?? 'MT',
      targetPrice: price,
      deliveryLocation: deliveryLoc,
      targetDate: targetDate,
      paymentTerms: paymentTerm,
      packagingType: _packagingController.text.trim().isNotEmpty
          ? _packagingController.text.trim()
          : 'Standard Trade Packaging',
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      visibility: selectedIds.isNotEmpty ? 'global' : _visibility,
      brokerId: selectedIds.isNotEmpty ? selectedIds.first : widget.initialBrokerId,
      brokerName: selectedIds.isNotEmpty
          ? _selectedBrokerNames[selectedIds.first]
          : widget.initialBrokerName,
      selectedBrokerIds: selectedIds,
      selectedBrokerNames: selectedNames,
    );

    try {
      final created = await _repo.createRequirement(dto);

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showSuccessDialog(created, notifiedNames: selectedNames);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showSuccessDialog(BuyerRequirement req, {List<String> notifiedNames = const []}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 24),
            SizedBox(width: 8),
            Text(
              'Requirement Created',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your mandate for ${req.quantity} ${req.unit} of ${req.commodityName} has been registered in the shared backend.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Requirement ID: ${req.id}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Target Delivery: ${DateFormat('dd MMM yyyy').format(req.targetDate)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  if (notifiedNames.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Notified Brokers (${notifiedNames.length}): ${notifiedNames.join(", ")}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (req.brokerName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Assigned Broker: ${req.brokerName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Distribution: Open Broadcast (All eligible desks)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/requirements');
            },
            child: const Text('View In Requirements', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Procurement Requirement'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _isLoadingMasterData
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Counterparty Shield Banner
                    _buildSecurityBanner(),
                    const SizedBox(height: 16),

                    // Broker Desk Assignment (if routed from broker profile)
                    if (widget.initialBrokerName != null) ...[
                      _buildBrokerAssignmentCard(),
                      const SizedBox(height: 16),
                    ],

                    if (_errorMessage != null) ...[
                      _buildErrorBanner(_errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Commodity Selection
                          _buildCommodityDropdown(),
                          const SizedBox(height: 16),

                          // 2. Grade Selection
                          _buildGradeDropdown(),
                          const SizedBox(height: 16),

                          // 3. Quantity & Unit
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: AppTextField(
                                  controller: _quantityController,
                                  label: 'Required Quantity *',
                                  hint: 'e.g. 100',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  prefixIcon: const Icon(LucideIcons.scale, size: 18),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _buildUnitDropdown(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 4. Expected Target Price
                          AppTextField(
                            controller: _priceController,
                            label: 'Target Price (₹/${_selectedUnit?.symbol ?? 'MT'}) *',
                            hint: 'e.g. 4850',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            prefixIcon: const Icon(LucideIcons.indianRupee, size: 18),
                          ),
                          const SizedBox(height: 16),

                          // 5. Delivery Location
                          _buildLocationSection(),
                          const SizedBox(height: 16),

                          // 6. Target Delivery Date
                          _buildTargetDatePicker(),
                          const SizedBox(height: 20),

                          const Divider(),
                          const SizedBox(height: 16),

                          // 7. Commercial Payment Preferences (Phase D)
                          _buildPaymentPreferencesSection(),
                          const SizedBox(height: 16),

                          // 8. Quality Specs & Packaging (Optional)
                          _buildOptionalDetailsSection(),
                          const SizedBox(height: 24),

                          const Divider(),
                          const SizedBox(height: 16),

                          // 9. Select Brokers to Notify (Phase B)
                          _buildBrokerSelectionSection(),
                          const SizedBox(height: 24),

                          // 10. Mandate Review Summary (Phase C)
                          _buildReviewSummarySection(),
                          const SizedBox(height: 28),

                          // 11. Submit Button with Duplicate Prevention
                          AppButton(
                            label: _selectedBrokerIds.isNotEmpty
                                ? 'Submit Requirement & Notify Brokers'
                                : 'Submit Procurement Requirement',
                            onPressed: _isSubmitting ? null : _handlePost,
                            isLoading: _isSubmitting,
                            variant: AppButtonVariant.primary,
                            icon: LucideIcons.send,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.shieldCheck, size: 18, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Counterparty Shield Protected: Your procurement requirement is processed exclusively through authorized mandi broker desks. Direct seller identities and contact details are never disclosed.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrokerAssignmentCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.briefcase, color: AppColors.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dedicated Mandate Routing',
                  style: TextStyle(fontSize: 11, color: AppColors.textMutedLight, fontWeight: FontWeight.w600),
                ),
                Text(
                  widget.initialBrokerName ?? 'Assigned Broker Desk',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _visibility == 'restricted' ? 'Direct Desk' : 'Global',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommodityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Commodity *',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        ),
        const SizedBox(height: 6),
        if (_isLoadingCommodities)
          _buildCommodityStatusBox(
            key: const Key('commodity-loading'),
            child: const Row(
              children: [
                SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Loading commodity catalogue...',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          )
        else if (_commodityLoadError != null)
          _buildCommodityStatusBox(
            key: const Key('commodity-load-error'),
            isError: true,
            child: Row(
              children: [
                const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _commodityLoadError!,
                    style: const TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ),
                TextButton(
                  key: const Key('commodity-retry'),
                  onPressed: _retryCommodities,
                  child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          )
        else if (_commodities.isEmpty)
          _buildCommodityStatusBox(
            key: const Key('commodity-empty'),
            child: Row(
              children: [
                const Icon(LucideIcons.info, size: 18, color: AppColors.textSecondaryLight),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No active commodities are available in the catalogue.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                ),
                TextButton(
                  onPressed: _retryCommodities,
                  child: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          )
        else
          InkWell(
            key: const Key('commodity-picker-field'),
            onTap: _openCommodityPicker,
            borderRadius: BorderRadius.circular(10),
            child: _buildCommodityStatusBox(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedCommodity?.name ?? 'Tap to select a commodity',
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedCommodity != null
                                ? AppColors.textPrimaryLight
                                : AppColors.textMutedLight,
                          ),
                        ),
                        if (_selectedCommodity != null) ...[
                          const SizedBox(height: 2),
                          CategoryLabel(categoryName: _selectedCommodity!.categoryName),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.textSecondaryLight),
                ],
              ),
            ),
          ),
        if (_unmatchedInitialCommodity != null) ...[
          const SizedBox(height: 6),
          Text(
            '"$_unmatchedInitialCommodity" is not in the current catalogue. Please select a commodity.',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
          ),
        ],
      ],
    );
  }

  Widget _buildCommodityStatusBox({Key? key, required Widget child, bool isError = false}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorBackground : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError ? AppColors.error.withValues(alpha: 0.3) : AppColors.borderLight,
        ),
      ),
      child: child,
    );
  }

  Widget _buildGradeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quality Grade',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        ),
        const SizedBox(height: 6),
        if (_selectedCommodity != null && _isLoadingGrades)
          _buildCommodityStatusBox(
            child: Text(
              'Loading grades for ${_selectedCommodity!.name}...',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
            ),
          )
        else if (_selectedCommodity != null && _gradeLoadError != null)
          _buildCommodityStatusBox(
            isError: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _gradeLoadError!,
                    style: const TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ),
                TextButton(
                  onPressed: () => _onCommodityChanged(_selectedCommodity),
                  child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          )
        else if (_selectedCommodity != null && _grades.isEmpty)
          _buildCommodityStatusBox(
            key: const Key('no-grade-notice'),
            isError: true,
            child: Text(
              _noGradeMessage(_selectedCommodity!.name),
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          )
        else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<MasterGrade>(
              isExpanded: true,
              value: _grades.contains(_selectedGrade) ? _selectedGrade : null,
              hint: Text(
                _selectedCommodity == null ? 'Select a commodity first' : 'Select grade',
                style: const TextStyle(fontSize: 14, color: AppColors.textMutedLight),
              ),
              items: _grades.map((g) {
                return DropdownMenuItem<MasterGrade>(
                  value: g,
                  child: Text(
                    g.gradeName,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimaryLight),
                  ),
                );
              }).toList(),
              onChanged: (g) {
                if (g != null) setState(() => _selectedGrade = g);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Unit *',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<MasterUnit>(
              isExpanded: true,
              value: _selectedUnit,
              items: _units.map((u) {
                return DropdownMenuItem<MasterUnit>(
                  value: u,
                  child: Text(
                    u.symbol,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimaryLight),
                  ),
                );
              }).toList(),
              onChanged: (u) {
                if (u != null) setState(() => _selectedUnit = u);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Delivery Location *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isCustomLocation = !_isCustomLocation;
                });
              },
              child: Text(
                _isCustomLocation ? 'Select Saved Mandi' : '+ Custom Location',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (!_isCustomLocation)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedLocation.isEmpty ? null : _selectedLocation,
                hint: const Text('Select delivery location', style: TextStyle(fontSize: 14)),
                items: _savedLocations.map((loc) {
                  return DropdownMenuItem<String>(
                    value: loc,
                    child: Text(
                      loc,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimaryLight),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLocation = val);
                },
              ),
            ),
          )
        else
          AppTextField(
            controller: _customLocationController,
            label: 'Enter Delivery Mandi / Factory',
            hint: 'e.g. FOR Factory Mill Depot, Kota',
            prefixIcon: const Icon(LucideIcons.mapPin, size: 18),
          ),
      ],
    );
  }

  Widget _buildTargetDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Required Delivery Date *',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _targetDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
            );
            if (picked != null) {
              setState(() => _targetDate = picked);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.calendar, size: 18, color: AppColors.textSecondaryLight),
                const SizedBox(width: 10),
                Text(
                  _targetDate == null
                      ? 'Select delivery date'
                      : DateFormat('dd MMMM yyyy').format(_targetDate!),
                  key: const Key('target-date-value'),
                  style: TextStyle(
                    fontSize: 14,
                    color: _targetDate == null
                        ? AppColors.textMutedLight
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.creditCard, size: 16, color: AppColors.primary),
            SizedBox(width: 6),
            Text(
              'Preferred Commercial Terms',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Buyer payment preference for broker-assisted deal negotiations. Not a binding commitment.',
          style: TextStyle(fontSize: 11, color: AppColors.textMutedLight),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedPaymentTerm,
              hint: const Text('Select payment terms', style: TextStyle(fontSize: 13)),
              items: _paymentOptions.map((term) {
                return DropdownMenuItem<String>(
                  value: term,
                  child: Text(
                    term,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryLight),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPaymentTerm = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionalDetailsSection() {
    return Material(
      color: Colors.transparent,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(
          'Additional Specifications (Optional)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight),
        ),
      children: [
        const SizedBox(height: 8),
        AppTextField(
          controller: _packagingController,
          label: 'Packaging Type',
          hint: 'e.g. 50kg New PP Bags, Loose Bulk',
          prefixIcon: const Icon(LucideIcons.package, size: 18),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _notesController,
          label: 'Mandate Notes for Broker Desk',
          hint: 'e.g. Quality inspection required at loading point.',
          maxLines: 2,
          prefixIcon: const Icon(LucideIcons.fileText, size: 18),
        ),
      ],
      ),
    );
  }

  Widget _buildBrokerSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.users, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Select Brokers to Notify',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _selectedBrokerIds.isNotEmpty
                    ? AppColors.primary
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedBrokerIds.isNotEmpty
                      ? AppColors.primary
                      : AppColors.borderLight,
                ),
              ),
              child: Text(
                _selectedBrokerIds.isNotEmpty
                    ? '${_selectedBrokerIds.length} Selected'
                    : 'Open Broadcast',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _selectedBrokerIds.isNotEmpty
                      ? Colors.white
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose verified broker desks to receive immediate mandate notifications. Unselected requirements remain open to all authorized desks.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryLight,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),

        // Search Bar for Brokers
        AppTextField(
          controller: _brokerSearchController,
          label: 'Search Brokers by Name or Mandi',
          hint: 'e.g. Varun, Jaipur, Kota Mandi...',
          prefixIcon: const Icon(LucideIcons.search, size: 18),
          suffixIcon: _brokerSearchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 16),
                  onPressed: () {
                    _brokerSearchController.clear();
                    _loadBrokers();
                  },
                )
              : null,
          onChanged: (val) => _loadBrokers(),
        ),
        const SizedBox(height: 10),

        // Filter chip for current commodity
        if (_selectedCommodity != null) ...[
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text(
                  'Specializing in ${_selectedCommodity!.name}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _filterBySelectedCommodity
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _filterBySelectedCommodity
                        ? AppColors.primaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                selected: _filterBySelectedCommodity,
                onSelected: (val) {
                  setState(() => _filterBySelectedCommodity = val);
                  _loadBrokers();
                },
                selectedColor: AppColors.primaryContainer,
                backgroundColor: AppColors.surfaceLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: _filterBySelectedCommodity
                        ? AppColors.primary
                        : AppColors.borderLight,
                  ),
                ),
              ),
              if (_selectedBrokerIds.isNotEmpty)
                ActionChip(
                  label: const Text('Deselect All', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _selectedBrokerIds.clear();
                      _selectedBrokerNames.clear();
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Broker List Area
        if (_isLoadingBrokers) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ] else if (_brokerSearchError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _brokerSearchError!,
                    style: const TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ),
                TextButton(
                  onPressed: _loadBrokers,
                  child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ] else if (_availableBrokers.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.info, size: 18, color: AppColors.textSecondaryLight),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No matching brokers found. You can still submit this requirement as an open broadcast mandate.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _availableBrokers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final broker = _availableBrokers[index];
              final isSelected = _selectedBrokerIds.contains(broker.id);

              return InkWell(
                onTap: () => _toggleBrokerSelection(broker),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryContainer.withValues(alpha: 0.35)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderLight,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Selection Indicator
                      Icon(
                        isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                        color: isSelected ? AppColors.primary : AppColors.textSecondaryLight,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    broker.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? AppColors.primaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (broker.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    LucideIcons.badgeCheck,
                                    size: 15,
                                    color: AppColors.success,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${broker.companyName ?? "Licensed Mandi Desk"}${broker.location != null ? " • ${broker.location}" : ""}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (broker.commoditiesHandled.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Specialties: ${broker.commoditiesHandled.take(3).join(", ")}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Text(
                          'Trust ${broker.trustScore}%',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],

        const SizedBox(height: 12),

        // Selected Recipients Summary Notice
        if (_selectedBrokerIds.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.successBackground.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.checkCheck, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_selectedBrokerIds.length} broker(s) selected: ${_selectedBrokerNames.values.join(", ")}. Direct mandate notifications will be delivered upon submission.',
                    style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.info, size: 16, color: AppColors.textSecondaryLight),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No brokers selected. This requirement will be posted as an open mandate without sending direct broker notifications.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewSummarySection() {
    final deliveryLoc = _isCustomLocation
        ? (_customLocationController.text.isNotEmpty
            ? _customLocationController.text
            : 'Custom Location')
        : _selectedLocation;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.clipboardCheck, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Review Mandate Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Commodity',
            _selectedCommodity == null
                ? 'Not selected'
                : '${_selectedCommodity!.name} (${_selectedGrade?.gradeName ?? "FAQ"})',
          ),
          _buildSummaryRow(
            'Quantity & Price',
            '${_quantityController.text} ${_selectedUnit?.symbol ?? "MT"} @ ₹${_priceController.text}/${_selectedUnit?.symbol ?? "MT"}',
          ),
          _buildSummaryRow('Delivery Location', deliveryLoc),
          _buildSummaryRow(
            'Required Date',
            _targetDate == null
                ? 'Not selected'
                : DateFormat('dd MMM yyyy').format(_targetDate!),
          ),
          _buildSummaryRow(
            'Selected Recipients',
            _selectedBrokerIds.isNotEmpty
                ? '${_selectedBrokerIds.length} Broker Desk(s)'
                : 'None (Open Mandate Broadcast)',
            valueColor: _selectedBrokerIds.isNotEmpty
                ? AppColors.primary
                : AppColors.textSecondaryLight,
          ),
          if (_selectedBrokerIds.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Recipients: ${_selectedBrokerNames.values.join(", ")}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
