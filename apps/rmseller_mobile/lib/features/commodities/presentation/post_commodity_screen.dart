import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../brokers/data/seller_broker_repository.dart';
import '../../brokers/domain/seller_broker_model.dart';
import '../../profile/data/seller_profile_repository.dart';
import '../../profile/domain/business_location_model.dart';
import '../../profile/presentation/seller_profile_screen.dart';
import '../../profile/domain/seller_commodity_expertise.dart';
import '../domain/posting_history.dart';
import '../data/commodities_repository.dart';
import '../data/lab_testing_repository.dart';
import '../domain/commodity_model.dart';
import '../domain/lab_testing_model.dart';
import '../domain/lot_location.dart';
import '../domain/master_commodity_data.dart';
import 'commodity_picker_sheet.dart';
import 'lot_location_sheet.dart';

class PostCommodityScreen extends StatefulWidget {
  final String? initialCommodityId;
  final String? initialBrokerId;
  final SellerCommodity? initialLot;
  final CommoditiesRepository? commoditiesRepository;
  final SellerProfileRepository? profileRepository;

  const PostCommodityScreen({
    super.key,
    this.initialCommodityId,
    this.initialBrokerId,
    this.initialLot,
    this.commoditiesRepository,
    this.profileRepository,
  });

  /// Unit preselected for a new lot: the "Metric Ton" MT row, else any MT row,
  /// else none (the seller must choose). Quantities are stored in the chosen
  /// unit, so preselecting never converts or relabels a value.
  static MasterUnit? defaultUnit(List<MasterUnit> units) {
    bool isMt(MasterUnit u) => u.symbol.trim().toUpperCase() == 'MT';
    for (final u in units) {
      if (isMt(u) && u.name.trim().toLowerCase() == 'metric ton') return u;
    }
    for (final u in units) {
      if (isMt(u)) return u;
    }
    return null;
  }

  /// The unit a saved lot was stored in, matched by ID, then by symbol.
  /// Returns null rather than substituting another unit, so a saved quantity
  /// is never shown under a different unit.
  static MasterUnit? unitForLot(List<MasterUnit> units, SellerCommodity lot) {
    for (final u in units) {
      if (lot.unitId != null && u.id == lot.unitId) return u;
    }
    final symbol = lot.unit.trim().toLowerCase();
    for (final u in units) {
      if (u.symbol.trim().toLowerCase() == symbol) return u;
    }
    return null;
  }

  /// Field error for the availability window, or null when valid. Compared by
  /// calendar day, so the same day for both is allowed.
  static String? validUntilError(DateTime availableFrom, DateTime validUntil) {
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    return day(validUntil).isBefore(day(availableFrom))
        ? 'Valid Until must be on or after Available From'
        : null;
  }

  @override
  State<PostCommodityScreen> createState() => _PostCommodityScreenState();
}

class _PostCommodityScreenState extends State<PostCommodityScreen> {
  final _formKey = GlobalKey<FormState>();
  late final CommoditiesRepository _commoditiesRepository =
      widget.commoditiesRepository ?? CommoditiesRepository();
  final SellerBrokerRepository _brokerRepository = SellerBrokerRepository();
  final LabTestingRepository _labTestingRepository = LabTestingRepository();
  late final SellerProfileRepository _profileRepository =
      widget.profileRepository ?? SellerProfileRepository();

  // Compact accordion (RB-SELLER-POST-UX-05): at most one section open.
  static const int _secCommodity = 0;
  static const int _secLocation = 1;
  static const int _secLab = 2;
  static const int _secBroker = 3;
  int? _openSection;

  /// True when the location summary came from the seller's saved profile
  /// location and has not been edited for this lot yet.
  bool _locationFromProfile = false;

  /// Whether a business location default exists on this device.
  bool _hasSavedBusinessLocation = false;

  /// Error message when fetching saved warehouse location failed.
  String? _savedLocationError;

  // Quick post (RB-SELLER-QUICK-POST-01).
  ListingReadiness? _readiness;
  PickerHistory _history = const PickerHistory.unavailable();

  bool _isLoadingMasterData = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Master Catalogs
  List<MasterCommodity> _commodities = [];
  List<MasterCommodity> _expertiseCommodities = [];
  bool _isLoadingExpertise = false;
  String? _commodityLoadError;
  List<MasterGrade> _grades = [];
  bool _isLoadingGrades = false;
  String? _gradeLoadError;
  List<MasterUnit> _units = [];
  List<MasterState> _states = [];
  List<MasterDistrict> _districts = [];
  List<SellerBrokerModel> _brokers = [];

  // Form State
  MasterCommodity? _selectedCommodity;
  MasterGrade? _selectedGrade;
  MasterUnit? _selectedUnit;
  MasterState? _selectedState;
  MasterDistrict? _selectedDistrict;

  // Warehouse / loading / office locations. The warehouse state & district are
  // _selectedState / _selectedDistrict; the rest is carried as text (see LotLocation).
  LotLocation _lotLocation = const LotLocation();

  // Mandi is no longer captured, but an edited lot keeps its stored value.
  String? _legacyMandiName;

  final TextEditingController _lotNumberController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _askingPriceController = TextEditingController();
  final TextEditingController _confidentialPriceController =
      TextEditingController();
  final TextEditingController _paymentTermsController = TextEditingController();
  final TextEditingController _labReportNumberController =
      TextEditingController();
  final TextEditingController _qualityRemarksController =
      TextEditingController();

  String _loadingStatus = 'Ready to Load';
  String _labReportType = 'NABL Certified Lab Report Available';
  String _paymentSchedule = 'Payment on Delivery (CAD)';
  DateTime _availableFrom = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 7));

  // Broker Selection State (UX-03)
  SellerBrokerModel? _selectedBroker;
  bool _filterBrokersByCommodity = true;

  // Optional Lab Testing State (RB-SELLER-LAB-01)
  bool _requestLabTesting = false; // Strictly optional
  final Set<String> _selectedLabTestIds = {
    'PARAM-CP',
    'PARAM-MOIST',
    'PARAM-ASH',
  };
  final TextEditingController _customTestParameterController =
      TextEditingController();
  LabTestingRequest? _currentLabRequest;
  bool _isInitiatingPayment = false;
  bool _isVerifyingPayment = false;

  // Lab Report Attachment State (UX-02)
  LabReportAttachment? _labAttachment;

  @override
  void initState() {
    super.initState();
    _loadMasterData();
    _lotNumberController.text =
        'LOT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _paymentTermsController.text = 'Payment on Delivery (CAD)';
    _labReportNumberController.text =
        'AGMARK-RAL-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    _qualityRemarksController.text =
        'FAQ Grade Cleaned, Moisture <= 9.5%, Foreign Matter < 1.0%';
  }

  @override
  void dispose() {
    _lotNumberController.dispose();
    _quantityController.dispose();
    _askingPriceController.dispose();
    _confidentialPriceController.dispose();
    _paymentTermsController.dispose();
    _labReportNumberController.dispose();
    _qualityRemarksController.dispose();
    _customTestParameterController.dispose();
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoadingMasterData = true);
    try {
      // The product catalogue loads on its own so a failure shows a retry instead of
      // blocking the whole form, and never falls back to a stale list.
      List<MasterCommodity> comms = [];
      String? commodityError;
      try {
        comms = await _commoditiesRepository.getMasterCommodities();
      } catch (e) {
        debugPrint('Product catalogue load failed: $e');
        commodityError =
            'Could not load the product catalogue. Check your connection and retry.';
      }
      final units = await _commoditiesRepository.getMasterUnits();
      final states = await _commoditiesRepository.getMasterStates();
      final brokers = await _brokerRepository.getBrokers();

      // Preselect only an exact ID match (route or edited lot); never the first product.
      final wantedId = widget.initialCommodityId ?? widget.initialLot?.commodityId;
      MasterCommodity? initialComm;
      for (final c in comms) {
        if (c.id == wantedId) initialComm = c;
      }

      List<MasterGrade> grades = [];
      String? gradeError;
      if (initialComm != null) {
        try {
          grades = await _commoditiesRepository.getMasterGrades(initialComm.id);
        } catch (e) {
          gradeError = 'Could not load grades for ${initialComm.name}.';
        }
      }
      MasterGrade? initialGrade;
      final wantedGradeId = widget.initialLot?.gradeId;
      for (final g in grades) {
        if (g.id == wantedGradeId) initialGrade = g;
      }
      initialGrade ??= grades.isNotEmpty ? grades.first : null;

      MasterState? initState;
      List<MasterDistrict> districts = [];
      MasterDistrict? initDistrict;

      if (widget.initialLot != null) {
        final lot = widget.initialLot!;
        _lotNumberController.text = lot.lotNumber;
        _quantityController.text = lot.totalQuantity.toString();
        _askingPriceController.text = lot.askingPrice.toString();
        if (lot.confidentialMinimumPrice != null) {
          _confidentialPriceController.text = lot.confidentialMinimumPrice
              .toString();
        }
        if (lot.paymentTerms != null) _paymentSchedule = lot.paymentTerms!;
        _legacyMandiName = lot.mandiName;
        if (lot.loadingStatus.isNotEmpty) _loadingStatus = lot.loadingStatus;
        if (lot.labReportNumber != null)
          _labReportNumberController.text = lot.labReportNumber!;
        if (lot.labName != null) {
          _labReportType = lot.labName!;
          if (lot.labName!.toLowerCase().contains('riddhi siddhi')) {
            _requestLabTesting = true;
            _currentLabRequest = _labTestingRepository
                .getRequestForAvailability(lot.id);
          }
        }
        _availableFrom = lot.availableFrom;
        _validUntil = lot.validUntil;

        if (lot.stateId != null && states.isNotEmpty) {
          initState = states.firstWhere(
            (s) => s.id == lot.stateId,
            orElse: () => states.first,
          );
        } else if (states.isNotEmpty) {
          initState = states.firstWhere(
            (s) => s.name.toLowerCase() == lot.stateName.toLowerCase(),
            orElse: () => states.first,
          );
        }

        if (initState != null) {
          districts = await _commoditiesRepository.getMasterDistricts(
            initState.id,
          );
          if (lot.districtId != null && districts.isNotEmpty) {
            initDistrict = districts.firstWhere(
              (d) => d.id == lot.districtId,
              orElse: () => districts.first,
            );
          } else if (districts.isNotEmpty) {
            initDistrict = districts.firstWhere(
              (d) =>
                  d.name.toLowerCase().contains(lot.districtName.toLowerCase()),
              orElse: () => districts.first,
            );
          }
        }
      }

      var initLocation = LotLocation.decode(
        warehouseText: widget.initialLot?.warehouseName,
        loadingText: widget.initialLot?.loadingRemarks,
        officeText: widget.initialLot?.officeLocation,
        warehouseState: initState,
        warehouseDistrict: initDistrict,
        states: states,
      );

      // New lot: start from the seller's saved profile location, if any. No
      // state or district is preselected otherwise (the seller adds one).
      var fromProfile = false;
      if (widget.initialLot == null) {
        final saved = await _loadSavedLocation(states);
        if (saved != null) {
          initState = saved.state;
          districts = saved.districts;
          initDistrict = saved.district;
          initLocation = saved.location;
          fromProfile = true;
          _hasSavedBusinessLocation = true;
        }
      }

      SellerBrokerModel? initialBroker;
      if (widget.initialBrokerId != null) {
        initialBroker = brokers.firstWhere(
          (b) => b.id == widget.initialBrokerId,
          orElse: () => brokers.first,
        );
      } else if (widget.initialLot?.brokerId != null) {
        initialBroker = brokers.firstWhere(
          (b) => b.id == widget.initialLot!.brokerId,
          orElse: () => brokers.first,
        );
      }

      if (!mounted) return;

      setState(() {
        _commodities = comms;
        _commodityLoadError = commodityError;
        _units = units;
        _states = states;
        _brokers = brokers;
        _selectedCommodity = initialComm;
        _grades = grades;
        _gradeLoadError = gradeError;
        _selectedGrade = initialGrade;
        _selectedUnit = widget.initialLot != null
            ? PostCommodityScreen.unitForLot(units, widget.initialLot!)
            : PostCommodityScreen.defaultUnit(units);
        _selectedState = initState;
        _districts = districts;
        _selectedDistrict = initDistrict;
        _lotLocation = initLocation;
        _locationFromProfile = fromProfile;
        // Open the first step while the commodity is still missing.
        _openSection ??= initialComm == null ? _secCommodity : null;
        if (initialBroker != null) {
          _selectedBroker = initialBroker;
        }
        _isLoadingMasterData = false;
      });
      // Non-blocking: the form is usable while these load.
      unawaited(_loadReadiness());
      unawaited(_loadHistory());
      unawaited(_loadExpertise());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load master trading data: $e';
        _isLoadingMasterData = false;
      });
    }
  }

  /// The saved profile location mapped onto the live state/district masters.
  /// Returns null when nothing was saved or the state is not in the master
  /// The saved profile location mapped onto the live state/district masters.
  /// Returns null when nothing was saved or the state is not in the master
  /// list; an unmatched district is left for the seller to pick.
  Future<
    ({
      MasterState state,
      List<MasterDistrict> districts,
      MasterDistrict? district,
      LotLocation location,
    })?
  >
  _loadSavedLocation(List<MasterState> states) async {
    try {
      final saved = await _profileRepository
          .getSavedBusinessLocation()
          .timeout(const Duration(seconds: 4));
      if (saved == null) {
        _savedLocationError = null;
        return null;
      }
      final state =
          states.where((s) => s.id == saved.stateId).firstOrNull ??
          states
              .where(
                (s) =>
                    s.name.toLowerCase() == saved.stateName.trim().toLowerCase(),
              )
              .firstOrNull;
      if (state == null) {
        _savedLocationError = null;
        return null;
      }
      final districts = await _commoditiesRepository.getMasterDistricts(
        state.id,
      );
      final district =
          districts.where((d) => d.id == saved.districtId).firstOrNull ??
          districts
              .where(
                (d) =>
                    d.name.toLowerCase() ==
                    saved.districtName.trim().toLowerCase(),
              )
              .firstOrNull;
      final office = await _profileRepository.getSavedOfficeAddress().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      final address = [
        saved.addressLine,
        saved.locality,
      ].where((s) => s.trim().isNotEmpty).join(', ');
      _savedLocationError = null;
      return (
        state: state,
        districts: districts,
        district: district,
        location: LotLocation(
          warehouse: LotAddress(
            label: saved.name,
            address: address,
            stateId: state.id,
            stateName: state.name,
            districtId: district?.id,
            districtName: district?.name ?? '',
            pinCode: saved.pinCode,
          ),
          // A distinct saved office stays separate; it is never replaced.
          officeSameAsWarehouse: office == null,
          office: office == null
              ? const LotAddress()
              : LotAddress(address: office),
        ),
      );
    } catch (e) {
      debugPrint('Saved profile location unavailable: $e');
      _savedLocationError = 'Could not load your saved warehouse location.';
      return null;
    }
  }

  /// Retries loading the saved warehouse location without discarding entered draft values.
  Future<void> _reloadSavedLocation() async {
    setState(() => _savedLocationError = null);
    try {
      final saved = await _loadSavedLocation(_states);
      if (!mounted) return;
      if (saved != null) {
        setState(() {
          _selectedState = saved.state;
          _districts = saved.districts;
          _selectedDistrict = saved.district;
          _lotLocation = saved.location;
          _locationFromProfile = true;
          _hasSavedBusinessLocation = true;
          _savedLocationError = null;
        });
      } else {
        setState(() => _savedLocationError = null);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _savedLocationError =
              'Could not load your saved warehouse location. Please check connection and retry.',
        );
      }
    }
  }

  /// Changes the product and reloads its grades. [preferredGradeId] (from the
  /// seller's posting history) is selected only if it is still a valid grade
  /// of this product. Nothing transaction-specific is copied.
  Future<void> _onCommodityChanged(
    MasterCommodity? newComm, {
    String? preferredGradeId,
  }) async {
    if (newComm == null) return;
    // Clear first so a grade of the previous product can never be submitted.
    setState(() {
      _selectedCommodity = newComm;
      _grades = [];
      _selectedGrade = null;
      _isLoadingGrades = true;
      _gradeLoadError = null;
    });

    try {
      final grades = await _commoditiesRepository.getMasterGrades(newComm.id);
      if (!mounted || _selectedCommodity?.id != newComm.id) return;
      setState(() {
        _grades = grades;
        _selectedGrade =
            grades.where((g) => g.id == preferredGradeId).firstOrNull ??
            (grades.isNotEmpty ? grades.first : null);
        _isLoadingGrades = false;
      });
    } catch (e) {
      if (!mounted || _selectedCommodity?.id != newComm.id) return;
      setState(() {
        _isLoadingGrades = false;
        _gradeLoadError = 'Could not load grades for ${newComm.name}.';
      });
    }
  }

  Future<void> _retryCommodities() async {
    setState(() => _commodityLoadError = null);
    try {
      final comms = await _commoditiesRepository.getMasterCommodities();
      if (!mounted) return;
      setState(() => _commodities = comms);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _commodityLoadError =
            'Could not load the product catalogue. Check your connection and retry.',
      );
    }
  }

  Future<void> _openCommodityPicker() async {
    final picked = await showCommodityPickerSheet(
      context: context,
      commodities: _commodities,
      selectedId: _selectedCommodity?.id,
      onRefresh: () async {
        final comms = await _commoditiesRepository.getMasterCommodities();
        if (mounted) setState(() => _commodities = comms);
        await _loadExpertise();
        return comms;
      },
      history: _history,
      onRetryHistory: () async {
        await _loadHistory();
        return _history;
      },
      expertiseCommodities: _expertiseCommodities,
    );
    if (picked != null && mounted) {
      await _onCommodityChanged(
        picked.commodity,
        preferredGradeId: picked.preferredGradeId,
      );
    }
  }

  /// Loads the authenticated seller's saved commodity expertise for priority display.
  /// Strictly non-blocking: failure falls back to normal catalog without blocking posting.
  Future<void> _loadExpertise() async {
    if (!mounted) return;
    setState(() => _isLoadingExpertise = true);
    try {
      final List<SellerCommodityExpertise> expertiseList =
          await _profileRepository.getSavedCommodityExpertise();
      if (!mounted) return;
      if (expertiseList.isEmpty || _commodities.isEmpty) {
        setState(() {
          _expertiseCommodities = [];
          _isLoadingExpertise = false;
        });
        return;
      }

      final mapped = <MasterCommodity>[];
      for (final exp in expertiseList) {
        if (exp.isApproved && exp.id.isNotEmpty) {
          final match = _commodities.firstWhere(
            (c) => c.id == exp.id,
            orElse: () => const MasterCommodity(id: '', name: '', code: ''),
          );
          if (match.id.isNotEmpty) {
            mapped.add(match);
            continue;
          }
        }
        final normMatch = _commodities.firstWhere(
          (c) => exp.matchesNormalized(c.name),
          orElse: () => const MasterCommodity(id: '', name: '', code: ''),
        );
        if (normMatch.id.isNotEmpty && !mapped.any((m) => m.id == normMatch.id)) {
          mapped.add(normMatch);
        }
      }

      setState(() {
        _expertiseCommodities = mapped;
        _isLoadingExpertise = false;
      });
    } catch (e) {
      debugPrint('Commodity expertise load notice: $e');
      if (mounted) {
        setState(() {
          _expertiseCommodities = [];
          _isLoadingExpertise = false;
        });
      }
    }
  }

  // ============================================================================
  // QUICK POST: posting history + business-profile readiness
  // (RB-SELLER-QUICK-POST-01)
  // ============================================================================

  /// The seller's real posting history (server only; never sample lots).
  Future<void> _loadHistory() async {
    PickerHistory history;
    try {
      final lots = await _commoditiesRepository.getPostingHistory();
      history = _commoditiesRepository.isOnline
          ? PickerHistory(items: PreviousCommodity.fromListings(lots))
          : const PickerHistory.unavailable();
    } on CommodityListException catch (e) {
      // A failed read is not "no history": say so; the catalogue still works.
      history = PickerHistory(
        error: 'Could not load your previously posted commodities. ${e.message}',
      );
    } catch (e) {
      debugPrint('Posting history load failed: ${e.runtimeType}');
      history = const PickerHistory(
        error: 'Could not load your previously posted commodities.',
      );
    }
    if (mounted) setState(() => _history = history);
  }

  /// Checks the firm details the backend needs (server-side). An error is
  /// "unable to verify", never "incomplete".
  Future<void> _loadReadiness() async {
    setState(() => _readiness = null);
    ListingReadiness readiness;
    try {
      readiness = await _profileRepository.checkListingReadiness().timeout(
        const Duration(seconds: 8),
        onTimeout: () => const ListingReadiness.unverified(
          'Checking your business profile took too long. Please retry.',
        ),
      );
    } catch (e) {
      debugPrint('Readiness check failed: ${e.runtimeType}');
      readiness = const ListingReadiness.unverified(
        'Could not check your business profile. Please retry.',
      );
    }
    if (!mounted) return;
    setState(() => _readiness = readiness);
    await _applyCompanyRegionDefault(readiness);
  }

  /// With no saved warehouse location, default the warehouse state/district to
  /// the firm's registered region on the server. The address is still asked.
  Future<void> _applyCompanyRegionDefault(ListingReadiness r) async {
    if (widget.initialLot != null || _selectedState != null) return;
    final state = _states.where((s) => s.id == r.companyStateId).firstOrNull;
    if (state == null) return;
    List<MasterDistrict> districts = const [];
    try {
      districts = await _commoditiesRepository.getMasterDistricts(state.id);
    } catch (_) {}
    if (!mounted || _selectedState != null) return;
    final district = districts
        .where((d) => d.id == r.companyDistrictId)
        .firstOrNull;
    setState(() {
      _selectedState = state;
      _districts = districts;
      _selectedDistrict = district;
      _locationFromProfile = true;
      _lotLocation = LotLocation(
        warehouse: LotAddress(
          stateId: state.id,
          stateName: state.name,
          districtId: district?.id,
          districtName: district?.name ?? '',
        ),
        officeSameAsWarehouse: _lotLocation.officeSameAsWarehouse,
        office: _lotLocation.office,
      );
    });
  }

  bool get _isFirstTimeSeller =>
      _history.available && _history.error == null && _history.items.isEmpty;

  /// What is still missing from the warehouse location, in plain words.
  List<String> get _missingLocationItems => [
    if (_lotLocation.warehouse.address.trim().isEmpty)
      'Warehouse / godown address',
    if (_selectedState == null) 'State',
    if (_selectedDistrict == null) 'District',
  ];

  Widget? _buildReadinessCard() {
    final r = _readiness;
    Widget card({
      required Key key,
      required Color color,
      required IconData icon,
      required String title,
      required List<String> lines,
      String? actionLabel,
      VoidCallback? onAction,
    }) {
      return Container(
        key: key,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 26),
                child: Text('• $l', style: const TextStyle(fontSize: 12)),
              ),
            if (actionLabel != null && onAction != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: onAction, child: Text(actionLabel)),
              ),
          ],
        ),
      );
    }

    if (r == null) {
      return const Padding(
        key: Key('readiness-checking'),
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'Checking your business profile…',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
        ),
      );
    }
    if (r.status == ListingReadinessStatus.unverified) {
      final isSessionExpired = r.error?.contains('session has expired') == true;
      return card(
        key: const Key('readiness-unverified'),
        color: AppColors.errorBackground,
        icon: LucideIcons.triangleAlert,
        title: isSessionExpired
            ? 'Session Expired'
            : 'Could not verify your business profile',
        lines: [r.error!],
        actionLabel: isSessionExpired ? 'Sign In Again' : 'Retry',
        onAction: isSessionExpired
            ? () => AppRouter.authNotifier.setUnauthenticated()
            : _loadReadiness,
      );
    }
    if (r.status == ListingReadinessStatus.incomplete) {
      return card(
        key: const Key('readiness-incomplete'),
        color: AppColors.errorBackground,
        icon: LucideIcons.building2,
        title: 'Business details needed before listing',
        lines: r.missing,
        actionLabel: 'Complete Profile',
        onAction: _openCompleteProfile,
      );
    }
    // Saved warehouse loading error: show retry banner without claiming location is missing (Case E)
    if (_savedLocationError != null) {
      return card(
        key: const Key('readiness-location-error'),
        color: AppColors.errorBackground,
        icon: LucideIcons.triangleAlert,
        title: 'Could not load your saved warehouse',
        lines: [_savedLocationError!],
        actionLabel: 'Retry',
        onAction: _reloadSavedLocation,
      );
    }
    // Firm verified; ask only for what the lot still lacks.
    if (!_locationComplete) {
      return card(
        key: const Key('readiness-location-missing'),
        color: Colors.amber.shade50,
        icon: LucideIcons.warehouse,
        title: _isFirstTimeSeller
            ? 'Complete your business details once'
            : 'Add your warehouse location',
        lines: _missingLocationItems,
        actionLabel: 'Add warehouse location',
        onAction: () => _openLocationPopup(highlightMissing: true),
      );
    }
    return null;
  }

  /// Opens the Profile screen to complete missing business/seller details,
  /// preserving all entered draft commodity lot fields.
  Future<void> _openCompleteProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SellerProfileScreen(isInitialEdit: true),
      ),
    );
    if (!mounted) return;
    await _loadReadiness();
  }

  Future<void> _openLocationPopup({bool highlightMissing = false}) async {
    List<BusinessLocationModel> savedWarehouses = const [];
    try {
      savedWarehouses = await _profileRepository.getSavedWarehouses();
    } catch (_) {}

    final result = await showLotLocationSheet(
      context: context,
      initial: _currentLotLocation(),
      states: _states,
      loadDistricts: _commoditiesRepository.getMasterDistricts,
      highlightMissing: highlightMissing,
      savedWarehouses: savedWarehouses,
    );
    if (result == null || !mounted) return;
    await _applyLotLocation(result);
  }

  LotLocation _currentLotLocation() {
    final l = _lotLocation;
    return LotLocation(
      warehouse: LotAddress(
        label: l.warehouse.label,
        address: l.warehouse.address,
        stateId: _selectedState?.id,
        stateName: _selectedState?.name ?? '',
        districtId: _selectedDistrict?.id,
        districtName: _selectedDistrict?.name ?? '',
        pinCode: l.warehouse.pinCode,
      ),
      loadingSameAsWarehouse: l.loadingSameAsWarehouse,
      loadingPoint: l.loadingPoint,
      loading: l.loading,
      officeSameAsWarehouse: l.officeSameAsWarehouse,
      office: l.office,
    );
  }

  String get _warehouseSummary {
    final s = _currentLotLocation().warehouse.summary;
    return s.isEmpty ? 'Not set' : s;
  }

  String get _loadingSummary {
    final l = _lotLocation;
    if (!l.loadingSameAsWarehouse) return l.loadingRemarksText;
    return [
      'Same as warehouse',
      l.loadingPoint,
    ].where((s) => s.isNotEmpty).join(' · ');
  }

  String get _officeSummary => _lotLocation.officeSameAsWarehouse
      ? 'Same as warehouse'
      : _lotLocation.office.summary;

  /// Copies the saved form into the lot draft and updates the persistent
  /// default warehouse for this seller.
  Future<void> _applyLotLocation(LotLocation result) async {
    final stateId = result.warehouse.stateId;
    final state = _states.where((s) => s.id == stateId).firstOrNull;
    var districts = _districts;
    if (state != null && state.id != _selectedState?.id) {
      districts = await _commoditiesRepository.getMasterDistricts(state.id);
    }
    if (!mounted) return;
    setState(() {
      _lotLocation = result;
      _locationFromProfile = false;
      _selectedState = state;
      _districts = districts;
      _selectedDistrict = districts
          .where((d) => d.id == result.warehouse.districtId)
          .firstOrNull;
    });

    var savedDefault = false;
    final w = result.warehouse;
    if (w.address.trim().isNotEmpty &&
        state != null &&
        _selectedDistrict != null) {
      try {
        await _profileRepository.saveBusinessLocationDefault(
          BusinessLocationModel(
            name: w.label,
            addressLine: w.address,
            locality: '',
            stateId: state.id,
            stateName: state.name,
            districtId: _selectedDistrict!.id,
            districtName: _selectedDistrict!.name,
            pinCode: w.pinCode,
            latitude: null,
            longitude: null,
          ),
          isUpdate: _hasSavedBusinessLocation,
        ).timeout(const Duration(seconds: 4));
        savedDefault = !_hasSavedBusinessLocation;
        _hasSavedBusinessLocation = true;
        _savedLocationError = null;
      } catch (e) {
        debugPrint('Saving default business location failed: ${e.runtimeType}');
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedDefault
              ? 'Location saved. It will be filled in for your next lot.'
              : 'Location details updated.',
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================================
  // LAB REPORT ATTACHMENT ACTIONS (UX-02)
  // ============================================================================

  void _openAttachmentActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.paperclip,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Attach Existing Lab Report',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(
                    LucideIcons.image,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Choose Image',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Select certificate image from device gallery (JPG, PNG)',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(
                    LucideIcons.fileText,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Choose Document',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Select a supported document, such as PDF',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickDocumentFile();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(
                    LucideIcons.camera,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Capture certificate photo using device camera',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _capturePhotoWithCamera();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.borderLight,
                  child: Icon(
                    LucideIcons.x,
                    color: AppColors.textPrimaryLight,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                onTap: () => Navigator.pop(sheetContext),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _generateReportReference(String fileName) {
    final lot = _lotNumberController.text.trim();
    final lotSegment = lot.isNotEmpty ? lot : 'LOT';
    final hashSegment = fileName.hashCode
        .abs()
        .toString()
        .padLeft(6, '0')
        .substring(0, 6);
    return 'DOC-REF-$lotSegment-$hashSegment';
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        final file = File(picked.path);
        int bytes = 0;
        try {
          bytes = await file.length();
        } catch (_) {}
        final name = picked.name.isNotEmpty
            ? picked.name
            : 'lab_certificate_${DateTime.now().millisecondsSinceEpoch}.jpg';
        setState(() {
          _labAttachment = LabReportAttachment(
            fileName: name,
            localFilePath: picked.path,
            fileSizeBytes: bytes,
            fileType: 'image',
            // Chosen on the device only; there is no upload pipeline yet.
            isUploaded: false,
            reportReference: _generateReportReference(name),
          );
        });
      }
      // Cancelled: nothing is attached (never a placeholder file).
    } catch (e) {
      debugPrint('Gallery picker failed: ${e.runtimeType}');
      _showAttachmentError('gallery');
    }
  }

  void _showAttachmentError(String source) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not open the $source. Check the app permission and try again.',
        ),
      ),
    );
  }

  Future<void> _pickDocumentFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );
      if (files.isNotEmpty) {
        final f = files.first;
        setState(() {
          _labAttachment = LabReportAttachment(
            fileName: f.name,
            localFilePath: f.path,
            fileSizeBytes: f.lengthSync() ?? 0,
            fileType: 'document',
            // Chosen on the device only; there is no upload pipeline yet.
            isUploaded: false,
            reportReference: _generateReportReference(f.name),
          );
        });
      }
      // Cancelled: nothing is attached (never a placeholder file).
    } catch (e) {
      debugPrint('Document picker failed: ${e.runtimeType}');
      _showAttachmentError('file picker');
    }
  }

  Future<void> _capturePhotoWithCamera() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        final file = File(photo.path);
        int bytes = 0;
        try {
          bytes = await file.length();
        } catch (_) {}
        final name = photo.name.isNotEmpty
            ? photo.name
            : 'camera_capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
        setState(() {
          _labAttachment = LabReportAttachment(
            fileName: name,
            localFilePath: photo.path,
            fileSizeBytes: bytes,
            fileType: 'image',
            // Chosen on the device only; there is no upload pipeline yet.
            isUploaded: false,
            reportReference: _generateReportReference(name),
          );
        });
      }
      // Cancelled: nothing is attached (never a placeholder file).
    } catch (e) {
      debugPrint('Camera capture failed: ${e.runtimeType}');
      _showAttachmentError('camera');
    }
  }

  Widget _buildLabReportAttachmentCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.fileCheck,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Lab Report (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              if (_labAttachment != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Attached',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Attach an existing lab report or quality certificate if available.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 10),
          if (_labAttachment == null) ...[
            OutlinedButton.icon(
              onPressed: _openAttachmentActionSheet,
              icon: const Icon(LucideIcons.paperclip, size: 16),
              label: const Text(
                'Add Lab Report',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _labAttachment!.isImage
                          ? LucideIcons.image
                          : LucideIcons.fileText,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _labAttachment!.fileName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_labAttachment!.isImage ? "Image Certificate" : "Quality Document"}${_labAttachment!.formattedSize.isNotEmpty ? " • ${_labAttachment!.formattedSize}" : ""}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        if (_labAttachment!.reportReference != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Ref: ${_labAttachment!.reportReference!} (Auto-generated)',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _openAttachmentActionSheet,
                    child: const Text(
                      'Replace',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.trash2,
                      size: 16,
                      color: AppColors.error,
                    ),
                    onPressed: () {
                      setState(() {
                        _labAttachment = null;
                      });
                    },
                    tooltip: 'Remove Attachment',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================================
  // BROKER SELECTION SECTION (UX-03)
  // ============================================================================

  void _openBrokerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final commName = _selectedCommodity?.name ?? '';
            final matchingBrokers = _brokers.where((b) {
              if (!_filterBrokersByCommodity || commName.isEmpty) return true;
              return b.commoditiesHandled.any(
                (c) =>
                    c.toLowerCase().contains(commName.toLowerCase()) ||
                    commName.toLowerCase().contains(c.toLowerCase()),
              );
            }).toList();

            final displayList = matchingBrokers.isNotEmpty
                ? matchingBrokers
                : _brokers;

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.briefcase,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Select Broker(s)',
                                style: AppTypography.titleMedium,
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(LucideIcons.x),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Commodity Relevance Filter Toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Filter by commodity: ${commName.isNotEmpty ? commName : "All"}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ),
                              FilterChip(
                                label: Text(
                                  _filterBrokersByCommodity
                                      ? 'Commodity Matched'
                                      : 'All Brokers',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _filterBrokersByCommodity
                                        ? AppColors.primary
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                                selected: _filterBrokersByCommodity,
                                selectedColor: AppColors.primaryContainer,
                                onSelected: (val) {
                                  setSheetState(() {
                                    _filterBrokersByCommodity = val;
                                  });
                                  setState(() {
                                    _filterBrokersByCommodity = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          final broker = displayList[index];
                          final isSelected = _selectedBroker?.id == broker.id;
                          final matches =
                              commName.isNotEmpty &&
                              broker.commoditiesHandled.any(
                                (c) =>
                                    c.toLowerCase().contains(
                                      commName.toLowerCase(),
                                    ) ||
                                    commName.toLowerCase().contains(
                                      c.toLowerCase(),
                                    ),
                              );

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.borderLight,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      broker.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (matches)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.successContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Specialist',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '${broker.companyName ?? ''} • ${broker.location ?? ''}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  if (broker.hasRatings)
                                    Row(
                                      children: [
                                        const Icon(
                                          LucideIcons.star,
                                          size: 12,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${broker.averageRating!.toStringAsFixed(1)} (${broker.reviewCount} reviews) • Trust: ${broker.trustScore}%',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.brown,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      'Trust Score: ${broker.trustScore}% • Mandi Phone: ${broker.mobile}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: isSelected
                                  ? const Icon(
                                      LucideIcons.checkCircle2,
                                      color: AppColors.primary,
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedBroker = broker;
                                });
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBrokerSelectionSection() {
    // Rendered inside the section card (UX-05), so no nested card chrome.
    return Builder(
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.users, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Select Broker(s)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              if (_selectedBroker != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '1 Selected',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose the broker or brokers you trust to handle this commodity.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 12),
          if (_selectedBroker == null) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _openBrokerPicker,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                ),
                icon: const Icon(LucideIcons.userPlus, size: 18),
                label: Text(
                  'Select Broker(s)',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge,
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryContainer,
                        child: Icon(
                          LucideIcons.userCheck,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedBroker!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_selectedCommodity != null &&
                                    _selectedBroker!.commoditiesHandled.any(
                                      (c) =>
                                          c.toLowerCase().contains(
                                            _selectedCommodity!.name
                                                .toLowerCase(),
                                          ) ||
                                          _selectedCommodity!.name
                                              .toLowerCase()
                                              .contains(c.toLowerCase()),
                                    ))
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.successContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Specialist',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_selectedBroker!.companyName ?? ""} • ${_selectedBroker!.location ?? ""}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_selectedBroker!.hasRatings) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    LucideIcons.star,
                                    size: 12,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_selectedBroker!.averageRating!.toStringAsFixed(1)} (${_selectedBroker!.reviewCount} reviews) • Trust: ${_selectedBroker!.trustScore}%',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.brown,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 2),
                              Text(
                                'Trust Score: ${_selectedBroker!.trustScore}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(LucideIcons.repeat, size: 14),
                        label: const Text(
                          'Change Broker',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: _openBrokerPicker,
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(
                          LucideIcons.x,
                          size: 14,
                          color: AppColors.textMutedLight,
                        ),
                        label: const Text(
                          'Remove',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMutedLight,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedBroker = null;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    // Duplicate submission guard: prevent concurrent submissions
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) return;

    final commodity = _selectedCommodity;
    if (commodity != null && !_isLoadingGrades && _gradeLoadError == null && _grades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_noGradeMessage(commodity.name))),
      );
      return;
    }
    if (commodity != null &&
        _selectedGrade != null &&
        _selectedGrade!.commodityId != commodity.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('The selected grade does not belong to ${commodity.name}'),
        ),
      );
      return;
    }

    if (_selectedCommodity == null ||
        _selectedGrade == null ||
        _selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select commodity, grade, and unit'),
        ),
      );
      return;
    }

    if (_selectedState == null || _selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select state and district warehouse location'),
        ),
      );
      return;
    }

    // Same rule as the field error and the review gate.
    final dateError = _dateError;
    if (dateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dateError)),
      );
      return;
    }

    final totalQty = double.tryParse(_quantityController.text.trim()) ?? 0;
    final askingPrice =
        double.tryParse(_askingPriceController.text.trim()) ?? 0;
    final confPrice = _confidentialPriceController.text.trim().isNotEmpty
        ? double.tryParse(_confidentialPriceController.text.trim())
        : widget.initialLot?.confidentialMinimumPrice;

    if (totalQty <= 0 || !totalQty.isFinite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Total quantity must be greater than zero'),
        ),
      );
      return;
    }

    if (askingPrice <= 0 || !askingPrice.isFinite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asking price must be positive')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final dto = CreateCommodityDto(
        commodityId: _selectedCommodity!.id,
        commodityName: _selectedCommodity!.name,
        gradeId: _selectedGrade!.id,
        gradeName: _selectedGrade!.gradeName,
        lotNumber: _lotNumberController.text.trim(),
        totalQuantity: totalQty,
        unitId: _selectedUnit!.id,
        unitSymbol: _selectedUnit!.symbol,
        askingPrice: askingPrice,
        confidentialMinimumPrice: confPrice,
        stateId: _selectedState!.id,
        stateName: _selectedState!.name,
        districtId: _selectedDistrict!.id,
        districtName: _selectedDistrict!.name,
        warehouseName: _lotLocation.warehouseText.isNotEmpty
            ? _lotLocation.warehouseText
            : null,
        mandiName: _legacyMandiName,
        loadingStatus: _loadingStatus,
        availableFrom: _availableFrom,
        validUntil: _validUntil,
        visibility: _selectedBroker != null ? 'restricted' : 'global',
        brokerId: _selectedBroker?.id,
        brokerName: _selectedBroker?.name,
        brokerPhone: _selectedBroker?.mobile,
        brokerLocation: _selectedBroker?.location,
        paymentTerms: _paymentSchedule,
        officeLocation: _lotLocation.officeText,
        loadingRemarks: _lotLocation.loadingRemarksText,
        labReportNumber: _requestLabTesting
            ? (_currentLabRequest?.id ??
                  'LAB-REQ-${_lotNumberController.text.trim().isNotEmpty ? _lotNumberController.text.trim() : "DRAFT"}')
            : (_labAttachment != null
                  ? (_labAttachment!.reportReference ??
                        'DOC-REF-${_lotNumberController.text.trim().isNotEmpty ? _lotNumberController.text.trim() : "LOT"}')
                  : null),
        labName: _requestLabTesting
            ? 'Riddhi Siddhi Laboratory (${_currentLabRequest?.paymentStatus.label ?? "Lab Testing Requested"})'
            : (_labAttachment != null
                  ? 'Attached: ${_labAttachment!.fileName}'
                  : 'No Lab Report Attached'),
        labReportFileName: _labAttachment?.fileName,
        // Only a real storage URL; a device path is not a report URL.
        labReportFileUrl: _labAttachment?.remoteStorageUrl,
      );

      final created = await _commoditiesRepository.createCommodity(dto);

      // If optional lab testing was requested, associate with the created lot
      if (_requestLabTesting && _currentLabRequest != null) {
        await _labTestingRepository.createTestingRequest(
          availabilityId: created.id,
          lotNumber: created.lotNumber,
          commodityName: created.commodityName,
          selectedTests: _currentLabRequest!.selectedTests,
          customNotes: _currentLabRequest!.customNotes,
        );
        if (_currentLabRequest!.isPaid) {
          // Never simulated: only an authoritative confirmation can verify.
          await _labTestingRepository.verifyPaymentWithBackend(
            availabilityId: created.id,
            transactionReference: _currentLabRequest!.transactionReference,
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Commodity Lot ${created.lotNumber} listed successfully on Mandi Network!',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      // Deep link to view saved listing details immediately
      context.pushReplacement('/commodities/${created.id}', extra: created);
    } on ListingSubmitException catch (e) {
      // Form values stay as entered so the seller can retry.
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      debugPrint('Listing submit failed: ${e.runtimeType}');
      if (!mounted) return;
      setState(() => _errorMessage = ListingSubmitException.generic);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ============================================================================
  // LAB TESTING HANDLERS (RB-SELLER-LAB-01)
  // ============================================================================

  Future<void> _handleInitiateUpiPayment() async {
    setState(() => _isInitiatingPayment = true);
    try {
      final selectedParams = _labTestingRepository
          .getRateCard()
          .where((p) => _selectedLabTestIds.contains(p.id))
          .toList();

      final tempAvailId = 'avail-${_lotNumberController.text.trim()}';
      final request = await _labTestingRepository.createTestingRequest(
        availabilityId: tempAvailId,
        lotNumber: _lotNumberController.text.trim(),
        commodityName: _selectedCommodity?.name ?? 'Commodity Lot',
        selectedTests: selectedParams,
        customNotes: _customTestParameterController.text.trim().isNotEmpty
            ? _customTestParameterController.text.trim()
            : null,
      );

      setState(() {
        _currentLabRequest = request;
      });

      final launched = await _labTestingRepository.launchUpiPayment(request);
      if (!mounted) return;

      setState(() {
        _currentLabRequest = _currentLabRequest?.copyWith(
          paymentStatus: LabPaymentStatus.paymentPending,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            launched
                ? 'UPI app opened for ₹${request.finalPayableAmount.toInt()}. Return to app to verify.'
                : 'UPI intent created. Use "Check Payment Status" to confirm.',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initiate UPI payment: $e')),
      );
    } finally {
      if (mounted) setState(() => _isInitiatingPayment = false);
    }
  }

  Future<void> _handleVerifyUpiPayment() async {
    if (_currentLabRequest == null) return;
    setState(() => _isVerifyingPayment = true);
    try {
      // Never simulated: a UPI reference alone does not prove payment.
      final verified = await _labTestingRepository.verifyPaymentWithBackend(
        availabilityId: _currentLabRequest!.availabilityId,
        transactionReference: _currentLabRequest!.transactionReference,
      );

      if (!mounted) return;
      setState(() {
        _currentLabRequest = verified;
      });

      if (verified.isPaid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verified. Testing request submitted.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        // Accurate: the app cannot confirm UPI payments itself.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment not confirmed yet. UPI payments must be verified by '
              'the RMBroker team before lab testing starts; your request stays '
              'pending until then.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment verification check error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isVerifyingPayment = false);
    }
  }

  Widget _buildPaymentActionCard(
    double estimatedTotal,
    bool isPaid,
    LabPaymentStatus paymentStatus,
  ) {
    if (isPaid) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.checkCircle2,
              color: AppColors.success,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paid — Payment Verified',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    'Amount: ₹${estimatedTotal.toInt()} • Ref: ${_currentLabRequest?.transactionReference ?? "VERIFIED"}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const Text(
                    'Testing request submitted to Riddhi Siddhi Laboratory. Administrator notified.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (paymentStatus == LabPaymentStatus.paymentPending) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.clock, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Payment Verification Pending',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.orange,
                    ),
                  ),
                ),
                if (_isVerifyingPayment)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Accurate: there is no automatic or in-app payment verification.
            const Text(
              'UPI payment was started. The app cannot confirm UPI payments; '
              'the RMBroker team must verify it before lab testing starts. '
              'Until then this request stays pending.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Check Status',
                    icon: LucideIcons.refreshCw,
                    variant: ButtonVariant.primary,
                    isLoading: _isVerifyingPayment,
                    onPressed: _isVerifyingPayment
                        ? null
                        : _handleVerifyUpiPayment,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Re-open UPI',
                    icon: LucideIcons.smartphone,
                    variant: ButtonVariant.outline,
                    onPressed: _isInitiatingPayment
                        ? null
                        : _handleInitiateUpiPayment,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Awaiting Payment State
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.shieldCheck,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Payment Method: UPI Only (GPay, PhonePe, Paytm, BHIM)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Pay via UPI — ₹${estimatedTotal.toInt()}',
          icon: LucideIcons.qrCode,
          isLoading: _isInitiatingPayment,
          onPressed: (_isInitiatingPayment || estimatedTotal <= 0)
              ? null
              : _handleInitiateUpiPayment,
        ),
      ],
    );
  }

  Widget _buildLabTestingSection() {
    final allParams = _labTestingRepository.getRateCard();
    final selectedParams = allParams
        .where((p) => _selectedLabTestIds.contains(p.id))
        .toList();
    final estimatedTotal = LabTestRateCard.calculateTotal(selectedParams);
    final isPaid = _currentLabRequest?.isPaid == true;
    final paymentStatus =
        _currentLabRequest?.paymentStatus ?? LabPaymentStatus.awaitingPayment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Optional toggle switch card
        Container(
          decoration: BoxDecoration(
            color: _requestLabTesting
                ? AppColors.primaryContainer.withValues(alpha: 0.25)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _requestLabTesting
                  ? AppColors.primary
                  : Colors.grey.shade300,
              width: _requestLabTesting ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                LucideIcons.flaskConical,
                color: _requestLabTesting
                    ? AppColors.primary
                    : AppColors.textSecondaryLight,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request Certified Lab Testing (Optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Partner: ${LabTestRateCard.laboratoryName}, Jaipur',
                      style: TextStyle(
                        fontSize: 11,
                        color: _requestLabTesting
                            ? AppColors.primary
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _requestLabTesting,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _requestLabTesting = val;
                    if (val && _selectedLabTestIds.isEmpty) {
                      _selectedLabTestIds.addAll([
                        'PARAM-CP',
                        'PARAM-MOIST',
                        'PARAM-ASH',
                      ]);
                    }
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_requestLabTesting) ...[
          // Read-only Testing Request Reference Indicator (UX-02)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.fileKey2,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Testing Request Reference (Auto-Generated)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        _currentLabRequest?.id ??
                            'LAB-REQ-${_lotNumberController.text.trim().isNotEmpty ? _lotNumberController.text.trim() : "DRAFT"}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Expanded Optional Lab Testing Sub-Workflow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Required Tests (Official Rate Card)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '${_selectedLabTestIds.length} Selected',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: allParams.map((param) {
              final isSelected = _selectedLabTestIds.contains(param.id);
              return FilterChip(
                selected: isSelected,
                selectedColor: AppColors.primaryContainer,
                checkmarkColor: AppColors.primary,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      param.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        param.priceLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                onSelected: isPaid
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected) {
                            _selectedLabTestIds.add(param.id);
                          } else {
                            if (_selectedLabTestIds.length > 1) {
                              _selectedLabTestIds.remove(param.id);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'At least one lab test must be selected.',
                                  ),
                                ),
                              );
                            }
                          }
                        });
                      },
              );
            }).toList(),
          ),

          if (_selectedLabTestIds.contains('PARAM-OTHER')) ...[
            const SizedBox(height: 10),
            AppTextField(
              controller: _customTestParameterController,
              label: 'Custom Parameter Specification',
              hint: 'Specify specific assay or test method (e.g. Aflatoxin B1)',
            ),
            const SizedBox(height: 4),
            const Text(
              'Notice: "Other" is subject to separate laboratory quotation; not billed upfront via UPI.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Charges Breakdown & Laboratory Details Card
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      LucideIcons.calculator,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Lab Charges Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 14),
                ...selectedParams
                    .where((p) => p.hasFixedPrice)
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '• ${p.name}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              p.priceLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (selectedParams.any((p) => !p.hasFixedPrice))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '• Other (Custom Parameter)',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          'Separate Lab Quote',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estimated Total',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₹${estimatedTotal.toInt()}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Final Payable Amount (UPI)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '₹${estimatedTotal.toInt()}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            LucideIcons.mapPin,
                            size: 14,
                            color: Colors.brown,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Laboratory Address & Submission Instructions:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.brown,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '${LabTestRateCard.laboratoryName}\n${LabTestRateCard.laboratoryAddress}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Instructions: Submit a sealed 500g representative sample clearly marked with Commodity Name, Lot Number, and Request Reference to the Jaipur laboratory.',
                        style: TextStyle(fontSize: 10, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Payment Status & Action
          _buildPaymentActionCard(estimatedTotal, isPaid, paymentStatus),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMasterData) {
      return const Scaffold(
        body: AppLoadingIndicator(
          message: 'Loading verified master trading catalogs...',
        ),
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy');
    final totalQty = double.tryParse(_quantityController.text.trim()) ?? 0;
    final askingPrice =
        double.tryParse(_askingPriceController.text.trim()) ?? 0;
    final totalVal = totalQty * askingPrice;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Post Commodity Lot')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Error banner if any
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.triangleAlert,
                      size: 20,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            ?_buildReadinessCard(),
            _buildLotBadge(),
            const SizedBox(height: 12),

            // RB-SELLER-POST-UX-05: four compact sections, one open at a time.
            _buildCollapsible(
              index: _secCommodity,
              icon: LucideIcons.package,
              title: '1. Commodity & Pricing',
              summary: _commoditySummary,
              complete: _commodityComplete,
              required: true,
              body: () => _buildCommodityDetails(totalVal, dateFormat),
            ),
            _buildCollapsible(
              index: _secLocation,
              icon: LucideIcons.mapPin,
              title: '2. Warehouse & Loading',
              summary: _locationSummaryLines,
              complete: _locationComplete,
              required: true,
              body: _buildLocationDetails,
            ),
            _buildCollapsible(
              index: _secLab,
              icon: LucideIcons.flaskConical,
              title: '3. Lab Testing & Reports',
              summary: _labSummaryLines,
              complete: true,
              body: () => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLabTestingSection(),
                  const SizedBox(height: 14),
                  _buildLabReportAttachmentCard(),
                ],
              ),
            ),
            _buildCollapsible(
              index: _secBroker,
              icon: LucideIcons.users,
              title: '4. My Trusted Broker',
              summary: _brokerSummaryLines,
              complete: true,
              body: _buildBrokerSelectionSection,
            ),
            const SizedBox(height: 16),

            // Duplicate guard: disabled while a submission is in flight.
            // Styled like AppButton, but the label can shrink on narrow screens.
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('review_and_list_button'),
                onPressed: _isSubmitting ? null : _openReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.send, size: 18),
                label: Text(
                  _isSubmitting ? 'Listing…' : 'Review & List Commodity',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // COMPACT SECTIONS & REVIEW (RB-SELLER-POST-UX-05)
  // ============================================================================

  double get _qty => double.tryParse(_quantityController.text.trim()) ?? 0;
  double get _price => double.tryParse(_askingPriceController.text.trim()) ?? 0;

  bool get _commodityComplete =>
      _selectedCommodity != null &&
      _selectedGrade != null &&
      _selectedUnit != null &&
      _qty > 0 &&
      _price > 0;

  // State/district are NOT NULL on availabilities; the warehouse address is
  // the business detail asked for once (RB-SELLER-QUICK-POST-01).
  bool get _locationComplete =>
      _selectedState != null &&
      _selectedDistrict != null &&
      _lotLocation.warehouse.address.trim().isNotEmpty;

  List<String> get _commoditySummary {
    final c = _selectedCommodity;
    if (c == null) return const ['Add commodity details'];
    final unit = _selectedUnit?.symbol ?? '';
    final qty = _quantityController.text.trim();
    final price = _askingPriceController.text.trim();
    return [
      '${c.name} · ${_selectedGrade?.gradeName ?? 'Select grade'}',
      qty.isEmpty || price.isEmpty
          ? 'Enter quantity and price'
          : '$qty $unit · ₹$price/$unit',
    ];
  }

  List<String> get _locationSummaryLines {
    if (!_locationComplete) {
      return [
        _locationFromProfile
            ? 'Saved address loaded · choose district'
            : 'Add warehouse location',
      ];
    }
    final w = _lotLocation.warehouse;
    final place = [
      if (w.label.isNotEmpty) w.label else if (w.address.isNotEmpty) w.address,
      '${_selectedDistrict!.name}, ${_selectedState!.name}',
    ].join(' · ');
    return [
      place,
      _lotLocation.loadingSameAsWarehouse
          ? 'Loading: same as warehouse'
          : 'Loading: separate location',
    ];
  }

  List<String> get _labSummaryLines => [
    _requestLabTesting ? 'Testing requested' : 'Testing not requested',
    _labAttachment != null ? 'Report attached' : 'No report attached',
  ];

  List<String> get _brokerSummaryLines {
    final b = _selectedBroker;
    if (b == null) return const ['No broker selected · open broker pool'];
    return [
      b.name,
      if ((b.location ?? '').isNotEmpty) b.location!,
    ];
  }

  Widget _buildCollapsible({
    required int index,
    required IconData icon,
    required String title,
    required List<String> summary,
    required bool complete,
    required Widget Function() body,
    bool required = false,
  }) {
    final open = _openSection == index;
    final attention = required && !complete;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        key: Key('post_section_$index'),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: attention && !open
                ? Colors.amber.shade300
                : Colors.grey.shade200,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: open,
              label: '$title. ${summary.join('. ')}',
              excludeSemantics: true,
              // Re-expose the tap that excludeSemantics hides from the InkWell.
              onTap: () => setState(() => _openSection = open ? null : index),
              child: InkWell(
                key: Key('post_section_header_$index'),
                onTap: () =>
                    setState(() => _openSection = open ? null : index),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.6,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (!open)
                              for (final line in summary)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    line,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                      if (attention && !open)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'To do',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      Icon(
                        open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        size: 20,
                        color: AppColors.textSecondaryLight,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (open) ...[
              Divider(height: 1, color: Colors.grey.shade200),
              Padding(padding: const EdgeInsets.all(14), child: body()),
            ],
          ],
        ),
      ),
    );
  }

  bool _showAdditionalDetails = false;

  Widget _buildCommodityDetails(double totalVal, DateFormat dateFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSection1(),
        const SizedBox(height: 14),
        _buildSection2(totalVal),
        const SizedBox(height: 10),
        InkWell(
          key: const Key('additional_details_toggle'),
          onTap: () =>
              setState(() => _showAdditionalDetails = !_showAdditionalDetails),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Additional Details (Optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Icon(
                  _showAdditionalDetails
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        if (_showAdditionalDetails) _buildAvailabilityDates(dateFormat),
      ],
    );
  }

  /// [d] limited to the picker window, so an edited lot with dates outside it
  /// cannot trip showDatePicker's initialDate assertion.
  static DateTime _clampDate(DateTime d, DateTime first, DateTime last) =>
      d.isBefore(first) ? first : (d.isAfter(last) ? last : d);

  String? get _dateError =>
      PostCommodityScreen.validUntilError(_availableFrom, _validUntil);

  Widget _buildAvailabilityDates(DateFormat dateFormat) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InkWell(
            key: const Key('available_from_field'),
            onTap: () async {
              final first = DateTime.now().subtract(const Duration(days: 30));
              final last = DateTime.now().add(const Duration(days: 90));
              final picked = await showDatePicker(
                context: context,
                initialDate: _clampDate(_availableFrom, first, last),
                firstDate: first,
                lastDate: last,
              );
              if (picked != null) setState(() => _availableFrom = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Available From'),
              child: Text(
                dateFormat.format(_availableFrom),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            key: const Key('valid_until_field'),
            onTap: () async {
              final first = DateTime.now();
              final last = DateTime.now().add(const Duration(days: 90));
              final picked = await showDatePicker(
                context: context,
                initialDate: _clampDate(_validUntil, first, last),
                firstDate: first,
                lastDate: last,
              );
              if (picked != null) setState(() => _validUntil = picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Valid Until *',
                errorText: _dateError,
                errorMaxLines: 2,
              ),
              child: Text(
                dateFormat.format(_validUntil),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationDetails() {
    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondaryLight),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_locationFromProfile)
          Container(
            key: const Key('location_from_profile_note'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _locationComplete
                  ? AppColors.successBackground
                  : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _locationComplete
                  ? 'Filled from your saved profile location. Edit it if this lot is elsewhere.'
                  // The saved district did not match the current district list.
                  : 'Your saved profile address is loaded, but its district '
                        'needs to be chosen again. Tap Add Location.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        if (!_locationComplete && !_locationFromProfile)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'No warehouse location yet. Add one to list this lot.',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          )
        else if (!_locationComplete)
          const SizedBox.shrink()
        else ...[
          row(LucideIcons.warehouse, 'Registered Warehouse', _warehouseSummary),
          row(LucideIcons.truck, 'Loading Location', _loadingSummary),
          row(LucideIcons.building2, 'Enterprise Office', _officeSummary),
        ],
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            key: const Key('edit_location_button'),
            onPressed: _openLocationPopup,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: Icon(
              _locationComplete ? LucideIcons.pencil : LucideIcons.plus,
              size: 16,
            ),
            label: Text(
              _locationComplete ? 'Edit Location' : 'Add Location',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Physical Loading Readiness *',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _loadingStatus,
          isExpanded: true,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: MasterCommodityData.verifiedLoadingStatuses
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _loadingStatus = val);
          },
        ),
      ],
    );
  }

  /// First required section that is incomplete, in on-screen order.
  int? _firstIncompleteSection() {
    if (!_commodityComplete || _dateError != null) return _secCommodity;
    if (!_locationComplete) return _secLocation;
    return null;
  }

  /// Validates, then shows the review. Only "List Commodity on Desk" in the
  /// review calls the existing [_handleSubmit].
  Future<void> _openReview() async {
    if (_isSubmitting) return;
    final missing = _firstIncompleteSection();
    if (missing != null) {
      setState(() {
        _openSection = missing;
        // The date fields live under Additional Details; show the error there.
        if (_dateError != null) _showAdditionalDetails = true;
      });
      // Let the opened section build so its field errors can show.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            missing == _secCommodity
                ? (_commodityComplete
                      ? _dateError!
                      : 'Complete commodity, grade, quantity and price.')
                : 'Add the warehouse location: ${_missingLocationItems.join(', ')}.',
          ),
        ),
      );
      return;
    }

    // The lot is filled in; the firm must also be verified on the server.
    final r = _readiness;
    if (r == null || r.status != ListingReadinessStatus.complete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r == null
                ? 'Still checking your business profile. Please try again in a moment.'
                : (r.error ?? r.missing.join(' ')),
          ),
          action: r?.status == ListingReadinessStatus.unverified
              ? SnackBarAction(label: 'Retry', onPressed: _loadReadiness)
              : (r?.status == ListingReadinessStatus.incomplete
                  ? SnackBarAction(
                      label: 'Complete Profile',
                      onPressed: _openCompleteProfile,
                    )
                  : null),
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? true)) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _buildReviewSheet(ctx),
    );
    if (confirmed == true && mounted) await _handleSubmit();
  }

  Widget _buildReviewSheet(BuildContext ctx) {
    final currencyFormat = NumberFormat('#,##,###');
    final dateFormat = DateFormat('dd MMM yyyy');
    final unit = _selectedUnit?.symbol ?? '(select unit)';
    final totalVal = _qty * _price;

    void edit(int section) {
      Navigator.pop(ctx, false);
      setState(() => _openSection = section);
    }

    Widget group(String title, int section, List<Widget> rows) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: Key('review_edit_$section'),
                onPressed: () => edit(section),
                child: const Text('Edit'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(children: rows),
          ),
        ],
      ),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Review & List Commodity',
                        style: AppTypography.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Lot ${_lotNumberController.text.trim()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                group('Commodity & Pricing', _secCommodity, [
                  _buildReviewRow('Commodity', _selectedCommodity?.name ?? ''),
                  _buildReviewRow(
                    'Category',
                    (_selectedCommodity?.categoryName ?? '').trim().isEmpty
                        ? 'Category unavailable'
                        : _selectedCommodity!.categoryName!,
                  ),
                  _buildReviewRow(
                    'Quality Grade',
                    _selectedGrade?.gradeName ?? '',
                  ),
                  _buildReviewRow(
                    'Supply Quantity',
                    '${_quantityController.text.trim()} $unit',
                  ),
                  _buildReviewRow(
                    'Asking Price',
                    '₹${_askingPriceController.text.trim()} per $unit',
                  ),
                  if (totalVal > 0)
                    _buildReviewRow(
                      'Estimated Gross Value',
                      '₹${currencyFormat.format(totalVal)}',
                      isHighlight: true,
                    ),
                  _buildReviewRow('Commercial Terms', _paymentSchedule),
                  _buildReviewRow(
                    'Availability',
                    '${dateFormat.format(_availableFrom)} – ${dateFormat.format(_validUntil)}',
                  ),
                ]),
                group('Locations', _secLocation, [
                  _buildReviewRow('Warehouse', _warehouseSummary),
                  _buildReviewRow(
                    'Loading Facility',
                    '$_loadingSummary ($_loadingStatus)',
                  ),
                  _buildReviewRow('Office HQ', _officeSummary),
                ]),
                group('Lab Testing & Reports', _secLab, [
                  if (_requestLabTesting) ...[
                    _buildReviewRow(
                      'Lab Testing (Optional)',
                      '${LabTestRateCard.laboratoryName} (${_selectedLabTestIds.length} tests)',
                      isHighlight: true,
                    ),
                    _buildReviewRow(
                      'Lab Payment Status',
                      _currentLabRequest?.paymentStatus.label ??
                          'Awaiting Payment',
                      isHighlight: _currentLabRequest?.isPaid == true,
                    ),
                  ] else
                    _buildReviewRow('Lab Testing', 'Not requested'),
                  _buildReviewRow(
                    'Lab Report',
                    _labAttachment != null
                        ? _labAttachment!.fileName
                        : 'No report attached',
                    isHighlight: _labAttachment != null,
                  ),
                ]),
                group('My Trusted Broker', _secBroker, [
                  _buildReviewRow(
                    'Trusted Broker Routing',
                    _selectedBroker != null
                        ? _selectedBroker!.name
                        : 'Open broker pool',
                    isHighlight: _selectedBroker != null,
                  ),
                ]),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AppButton(
                key: const Key('confirm_list_button'),
                label: 'List Commodity on Desk',
                onPressed: () => Navigator.pop(ctx, true),
                icon: LucideIcons.send,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _noGradeMessage(String productName) =>
      'No grade is defined for $productName in the Product Master yet. '
      'It cannot be listed until a grade is added.';

  Widget _buildStatusBox({
    Key? key,
    required String message,
    bool isError = false,
    VoidCallback? onRetry,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorBackground : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: isError ? AppColors.error : AppColors.textSecondaryLight,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  /// Tappable product field: name plus the authoritative category label.
  Widget _buildCommodityField() {
    if (_commodityLoadError != null) {
      return _buildStatusBox(
        key: const Key('commodity-load-error'),
        message: _commodityLoadError!,
        isError: true,
        onRetry: _retryCommodities,
      );
    }
    if (_commodities.isEmpty) {
      return _buildStatusBox(
        key: const Key('commodity-empty'),
        message: 'No active products are available in the catalogue.',
        onRetry: _retryCommodities,
      );
    }
    final sel = _selectedCommodity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_expertiseCommodities.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.sparkles, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'My Expertise',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final exp in _expertiseCommodities)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            key: Key('quick-expertise-chip-${exp.id}'),
                            avatar: Icon(
                              sel?.id == exp.id ? LucideIcons.check : LucideIcons.sparkles,
                              size: 13,
                              color: sel?.id == exp.id ? Colors.white : AppColors.primary,
                            ),
                            label: Text(
                              exp.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: sel?.id == exp.id ? FontWeight.w700 : FontWeight.w500,
                                color: sel?.id == exp.id ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                            backgroundColor: sel?.id == exp.id ? AppColors.primary : Colors.grey.shade50,
                            side: BorderSide(
                              color: sel?.id == exp.id ? AppColors.primary : AppColors.borderLight,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            onPressed: () => _onCommodityChanged(exp),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        InkWell(
          key: const Key('commodity-picker-field'),
          onTap: _openCommodityPicker,
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: Icon(LucideIcons.search, size: 18),
            ),
            child: sel == null
                ? const Text(
                    'Tap to search products',
                    style: TextStyle(fontSize: 14, color: AppColors.textMutedLight),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sel.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      CategoryLabel(categoryName: sel.categoryName),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  /// Only the selected product's own grades, with loading / error / no-grade states.
  Widget _buildGradeField() {
    final sel = _selectedCommodity;
    if (sel != null && _isLoadingGrades) {
      return _buildStatusBox(message: 'Loading grades for ${sel.name}...');
    }
    if (sel != null && _gradeLoadError != null) {
      return _buildStatusBox(
        message: _gradeLoadError!,
        isError: true,
        onRetry: () => _onCommodityChanged(sel),
      );
    }
    if (sel != null && _grades.isEmpty) {
      return _buildStatusBox(
        key: const Key('no-grade-notice'),
        message: _noGradeMessage(sel.name),
        isError: true,
      );
    }
    return DropdownButtonFormField<MasterGrade>(
      key: ValueKey('grade-field-${sel?.id}'),
      initialValue: _grades.contains(_selectedGrade) ? _selectedGrade : null,
      isExpanded: true,
      hint: Text(sel == null ? 'Select a product first' : 'Select grade'),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: _grades.map((g) {
        return DropdownMenuItem(
          value: g,
          child: Text(
            g.gradeName,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: sel == null ? null : (g) => setState(() => _selectedGrade = g),
    );
  }

  Widget _buildFormFieldWrapper({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  /// Batch / Lot No. shown once at the top; its generation lifecycle is unchanged.
  Widget _buildLotBadge() {
    final lot = _lotNumberController.text.trim();
    if (lot.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: 'Batch and Lot Number $lot',
      child: Container(
        key: const Key('section1_batch_lot_label'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Text(
              'BATCH / LOT NO.  ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.textSecondaryLight,
              ),
            ),
            Expanded(
              child: Text(
                lot,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Commodity search + grade (expanded Commodity & Pricing, part 1).
  Widget _buildSection1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (_) => LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;
              final commodityDropdown = _buildFormFieldWrapper(
                label: 'Commodity *',
                child: KeyedSubtree(
                  key: const Key('commodity_dropdown'),
                  child: _buildCommodityField(),
                ),
              );

              final gradeDropdown = _buildFormFieldWrapper(
                label: 'Quality Grade *',
                child: KeyedSubtree(
                  key: const Key('grade_dropdown'),
                  child: _buildGradeField(),
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: commodityDropdown),
                    const SizedBox(width: 14),
                    Expanded(child: gradeDropdown),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  commodityDropdown,
                  const SizedBox(height: 14),
                  gradeDropdown,
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Quantity, unit, price and terms (expanded Commodity & Pricing, part 2).
  Widget _buildSection2(double totalVal) {
    final currencyFormat = NumberFormat('#,##,###');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (_) => LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;

              // Quantity field
              final quantityField = _buildFormFieldWrapper(
                label: 'Total Quantity *',
                child: TextFormField(
                  key: const Key('quantity_field'),
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter quantity',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final n = double.tryParse(val);
                    if (n == null || n <= 0) return 'Must be > 0';
                    return null;
                  },
                ),
              );

              // Unit field
              final unitField = _buildFormFieldWrapper(
                label: 'Unit *',
                child: DropdownButtonFormField<MasterUnit>(
                  key: const Key('unit_dropdown'),
                  value: _selectedUnit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: _units.map((u) {
                    return DropdownMenuItem(value: u, child: Text(u.symbol));
                  }).toList(),
                  onChanged: (u) => setState(() => _selectedUnit = u),
                ),
              );

              // Asking Price field
              final askingPriceField = _buildFormFieldWrapper(
                label:
                    'Asking Price (₹ per ${_selectedUnit?.symbol ?? 'unit'}) *',
                child: TextFormField(
                  key: const Key('asking_price_field'),
                  controller: _askingPriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter price',
                    prefixIcon: Icon(
                      LucideIcons.indianRupee,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final p = double.tryParse(val);
                    if (p == null || p <= 0) return 'Must be positive';
                    return null;
                  },
                ),
              );

              // Payment Terms field
              final paymentTermsField = _buildFormFieldWrapper(
                label: 'Commercial Payment Terms *',
                child: DropdownButtonFormField<String>(
                  key: const Key('payment_terms_dropdown'),
                  value: _paymentSchedule,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Payment on Delivery (CAD)',
                      child: Text(
                        'Payment on Delivery (CAD)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Advance RTGS (50% Advance / 50% on B/L)',
                      child: Text(
                        'Advance RTGS (50/50)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Immediate RTGS on Weighbridge Slip',
                      child: Text(
                        'Immediate RTGS on Weighbridge',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Letter of Credit (LC at Sight)',
                      child: Text(
                        'Letter of Credit (LC)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _paymentSchedule = val);
                  },
                ),
              );

              // Live Valuation Card (Section 2)
              final valuationWidget = totalVal > 0
                  ? Container(
                      key: const Key('section2_live_valuation'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estimated Gross Lot Value',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          Text(
                            'Est. Value: ₹${currencyFormat.format(totalVal)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink();

              if (isWide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: quantityField),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: unitField),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: askingPriceField),
                      ],
                    ),
                    const SizedBox(height: 14),
                    paymentTermsField,
                    valuationWidget,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: quantityField),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: unitField),
                    ],
                  ),
                  const SizedBox(height: 14),
                  askingPriceField,
                  const SizedBox(height: 14),
                  paymentTermsField,
                  valuationWidget,
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isHighlight
                    ? AppColors.primary
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
