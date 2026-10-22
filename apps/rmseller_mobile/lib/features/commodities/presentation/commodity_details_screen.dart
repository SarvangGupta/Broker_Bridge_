import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../brokers/data/seller_broker_repository.dart';
import '../../brokers/domain/seller_broker_model.dart';
import '../data/commodities_repository.dart';
import '../data/lab_testing_repository.dart';
import '../domain/commodity_model.dart';
import '../domain/lab_testing_model.dart';

class CommodityDetailsScreen extends StatefulWidget {
  final String commodityId;
  final SellerCommodity? initialCommodity;

  const CommodityDetailsScreen({
    super.key,
    required this.commodityId,
    this.initialCommodity,
  });

  @override
  State<CommodityDetailsScreen> createState() => _CommodityDetailsScreenState();
}

class _CommodityDetailsScreenState extends State<CommodityDetailsScreen> {
  final CommoditiesRepository _repository = CommoditiesRepository();
  final SellerBrokerRepository _brokerRepository = SellerBrokerRepository();
  final ContactLauncherService _contactLauncher =
      const ContactLauncherService();
  final LabTestingRepository _labTestingRepository = LabTestingRepository();

  SellerCommodity? _commodity;
  bool _isLoading = true;
  bool _isActionInProgress = false;

  // Lab Testing State (RB-SELLER-LAB-01)
  LabTestingRequest? _labRequest;
  bool _isReportAvailable = false;
  String? _signedReportUrl;
  String _labStatus = 'Pending';
  String? _labReportNumber;

  @override
  void initState() {
    super.initState();
    if (widget.initialCommodity != null) {
      _commodity = widget.initialCommodity;
      _isLoading = false;
      _loadLabDetails();
    } else {
      _loadCommodity();
    }
  }

  Future<void> _loadCommodity() async {
    setState(() => _isLoading = true);
    final item = await _repository.getCommodityById(widget.commodityId);
    if (!mounted) return;
    setState(() {
      _commodity = item;
      _isLoading = false;
    });
    _loadLabDetails();
  }

  Future<void> _loadLabDetails() async {
    try {
      final req = _labTestingRepository.getRequestForAvailability(
        widget.commodityId,
      );
      final details = await _labTestingRepository.getLabReportDetails(
        widget.commodityId,
      );

      if (!mounted) return;
      setState(() {
        _labRequest = req;
        _isReportAvailable = details.isAvailable;
        _signedReportUrl = details.reportUrl;
        _labStatus = details.status;
        _labReportNumber = details.reportNumber;
      });
    } catch (e) {
      debugPrint('Error loading lab details: $e');
    }
  }

  Future<void> _showUpdatePriceDialog() async {
    if (_commodity == null) return;
    final priceController = TextEditingController(
      text: _commodity!.askingPrice.toStringAsFixed(0),
    );

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Asking Price'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Asking Price: ₹${_commodity!.askingPrice.toStringAsFixed(0)} / ${_commodity!.unit}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: priceController,
                label: 'New Asking Price (₹) *',
                hint: 'e.g. 5200',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Save Price',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (updated == true && mounted) {
      final newPrice = double.tryParse(priceController.text.trim());
      if (newPrice != null && newPrice > 0) {
        setState(() => _isActionInProgress = true);
        await _repository.updateCommodityPrice(_commodity!.id, newPrice);
        if (!mounted) return;
        setState(() {
          _commodity = _commodity!.copyWith(askingPrice: newPrice);
          _isActionInProgress = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Asking price updated to ₹${newPrice.toStringAsFixed(0)} successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _confirmStatusUpdate(
    String newStatus,
    String actionLabel,
  ) async {
    if (_commodity == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$actionLabel Lot?'),
          content: Text(
            'Are you sure you want to mark lot "${_commodity!.lotNumber}" as $newStatus? This update will be recorded in the Mandi trading network.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: newStatus == 'Cancelled'
                    ? AppColors.error
                    : AppColors.primary,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                actionLabel,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isActionInProgress = true);
      await _repository.updateCommodityStatus(_commodity!.id, newStatus);
      if (!mounted) return;
      setState(() {
        _commodity = _commodity!.copyWith(status: newStatus);
        _isActionInProgress = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lot status updated to $newStatus.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _openChangeBrokersSheet(SellerCommodity lot) async {
    if (_isActionInProgress) return;

    List<SellerBrokerModel> brokers = [];
    try {
      brokers = await _brokerRepository.getBrokers();
    } catch (e) {
      debugPrint('Failed to load brokers for reassignment: $e');
    }

    if (!mounted) return;

    SellerBrokerModel? selectedBroker;

    final confirmedBroker = await showModalBottomSheet<SellerBrokerModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                                LucideIcons.repeat,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Change Mandi Broker',
                                style: AppTypography.titleMedium,
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(LucideIcons.x),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.userCheck,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Currently Assigned: ${lot.brokerName ?? "Open Mandi Pool"}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Select a licensed broker from the verified registry below:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
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
                        itemCount: brokers.length,
                        itemBuilder: (context, index) {
                          final broker = brokers[index];
                          final isCurrentlyAssigned = lot.brokerId == broker.id;
                          final isNewlySelected =
                              selectedBroker?.id == broker.id;

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isNewlySelected
                                    ? AppColors.primary
                                    : (isCurrentlyAssigned
                                          ? AppColors.success
                                          : AppColors.borderLight),
                                width: isNewlySelected || isCurrentlyAssigned
                                    ? 2
                                    : 1,
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
                                  if (isCurrentlyAssigned)
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
                                        'Current',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  else if (isNewlySelected)
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
                                        'New Selection',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
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
                                            fontSize: 10,
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
                                        fontSize: 10,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: isNewlySelected
                                  ? const Icon(
                                      LucideIcons.checkCircle2,
                                      color: AppColors.primary,
                                    )
                                  : (isCurrentlyAssigned
                                        ? const Icon(
                                            LucideIcons.badgeCheck,
                                            color: AppColors.success,
                                          )
                                        : null),
                              onTap: isCurrentlyAssigned
                                  ? null
                                  : () {
                                      setSheetState(() {
                                        selectedBroker = isNewlySelected
                                            ? null
                                            : broker;
                                      });
                                    },
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: AppButton(
                        label: selectedBroker != null
                            ? 'Review & Confirm Change'
                            : 'Select a Broker Above',
                        onPressed: selectedBroker != null
                            ? () => Navigator.pop(context, selectedBroker)
                            : null,
                        icon: LucideIcons.arrowRight,
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

    if (confirmedBroker == null || !mounted) return;

    // Concise Review Confirmation Dialog (UX-04 requirement)
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(LucideIcons.alertCircle, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Confirm Broker Change'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to change the broker mandate for lot ${lot.lotNumber}?',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Previous: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            lot.brokerName ?? 'Open Mandi Pool',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${confirmedBroker.name} (${confirmedBroker.location})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'All future trading discussions and counterparty bids will be routed exclusively to the new broker.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Confirm Change',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (shouldProceed != true || !mounted) return;

    // Guard duplicate execution
    setState(() => _isActionInProgress = true);

    try {
      final success = await _repository.updateCommodityBroker(
        lot.id,
        brokerId: confirmedBroker.id,
        brokerName: confirmedBroker.name,
        brokerPhone: confirmedBroker.mobile,
        brokerLocation: confirmedBroker.location,
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _commodity = _commodity!.copyWith(
            brokerId: confirmedBroker.id,
            brokerName: confirmedBroker.name,
            brokerPhone: confirmedBroker.mobile,
            brokerLocation: confirmedBroker.location,
          );
          _isActionInProgress = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Mandi broker desk changed to ${confirmedBroker.name} successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() => _isActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to update broker assignment. Existing broker assignment preserved.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionInProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error updating broker: $e. Existing assignment preserved.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppLoadingIndicator(message: 'Loading lot details...'),
      );
    }

    if (_commodity == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lot Details')),
        body: const Center(child: Text('Commodity lot not found')),
      );
    }

    final lot = _commodity!;
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat('#,##,###');
    final effectiveBrokerPhone = lot.brokerPhone ?? '+919829012345';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(lot.lotNumber),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Refresh Lot',
            onPressed: _loadCommodity,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        lot.commodityName,
                        style: AppTypography.titleLarge,
                      ),
                    ),
                    StatusBadge(status: lot.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lot.gradeName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.mapPin,
                      size: 14,
                      color: AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${lot.districtName}, ${lot.stateName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        lot.loadingStatus,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Inventory & Commercial Breakdown Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory & Pricing Breakdown',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: 14),

                // Volume Progress Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildVolumePill(
                      'Total Lot',
                      '${lot.totalQuantity.toInt()} ${lot.unit}',
                      AppColors.primary,
                    ),
                    _buildVolumePill(
                      'Available',
                      '${lot.availableQuantity.toInt()} ${lot.unit}',
                      AppColors.success,
                    ),
                    _buildVolumePill(
                      'Reserved',
                      '${lot.reservedQuantity.toInt()} ${lot.unit}',
                      AppColors.warning,
                    ),
                    _buildVolumePill(
                      'Sold',
                      '${lot.soldQuantity.toInt()} ${lot.unit}',
                      AppColors.textMutedLight,
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Price Rows
                _buildInfoRow(
                  'Asking Price',
                  '₹${currencyFormat.format(lot.askingPrice)} / ${lot.unit}',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Estimated Gross Value',
                  '₹${currencyFormat.format(lot.totalEstimatedValue)}',
                ),
                if (lot.confidentialMinimumPrice != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Confidential Floor Price',
                    '₹${currencyFormat.format(lot.confidentialMinimumPrice!)} / ${lot.unit}',
                  ),
                ],
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Payment Terms',
                  lot.paymentTerms ?? 'Payment on Delivery (CAD)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Physical Dispatch & Facility Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dispatch & Warehouse Location',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: 12),
                if (lot.warehouseName != null &&
                    lot.warehouseName!.isNotEmpty) ...[
                  _buildInfoRow('Warehouse Address', lot.warehouseName!),
                  const SizedBox(height: 8),
                ],
                if (lot.mandiName != null && lot.mandiName!.isNotEmpty) ...[
                  _buildInfoRow('Mandi Hub', lot.mandiName!),
                  const SizedBox(height: 8),
                ],
                _buildInfoRow(
                  'Loading Facility',
                  lot.loadingRemarks ?? 'Krishi Upaj Mandi Yard Warehouse A-4',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Mandi District',
                  '${lot.districtName}, ${lot.stateName}',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Registered Office HQ',
                  lot.officeLocation ?? 'Bikaner Commercial Head Office',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Ready From',
                  dateFormat.format(lot.availableFrom),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Offer Valid Until',
                  dateFormat.format(lot.validUntil),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Lab Certificate',
                  lot.labReportNumber ?? 'AGMARK-RAL-2026-9021',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Laboratory Testing & Report Card (RB-SELLER-LAB-01)
          _buildLabTestingCard(lot),
          const SizedBox(height: 16),

          // Assigned Mandi Broker Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('My Trusted Broker', style: AppTypography.titleMedium),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Licensed Broker',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  lot.brokerName ?? 'Regional Mandi Broadcast Desk',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  lot.brokerLocation ?? 'Krishi Upaj Mandi Yard B-Block',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Counterparty Shield: All buyer negotiations and trade contracts are strictly broker-mediated. Direct buyer access is prohibited.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _contactLauncher.launchPhone(effectiveBrokerPhone),
                        icon: const Icon(LucideIcons.phone, size: 16),
                        label: const Text('Call Broker'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _contactLauncher.launchWhatsApp(
                          effectiveBrokerPhone,
                        ),
                        icon: const Icon(LucideIcons.messageCircle, size: 16),
                        label: const Text('WhatsApp'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green.shade700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Broker Chat & Commission Desk',
                  onPressed: () => context.push(
                    '/commodities/${lot.id}/negotiate',
                    extra: lot,
                  ),
                  variant: ButtonVariant.primary,
                  icon: LucideIcons.messageSquare,
                ),
                if (lot.isActive) ...[
                  const SizedBox(height: 10),
                  AppButton(
                    label: 'Change Brokers',
                    onPressed: _isActionInProgress
                        ? null
                        : () => _openChangeBrokersSheet(lot),
                    variant: ButtonVariant.outline,
                    icon: LucideIcons.repeat,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Supported Management Actions
          if (lot.isActive) ...[
            AppButton(
              label: 'Update Asking Price',
              onPressed: _isActionInProgress ? null : _showUpdatePriceDialog,
              variant: ButtonVariant.primary,
              icon: LucideIcons.indianRupee,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Mark as Fulfilled / Dispatched',
              onPressed: _isActionInProgress
                  ? null
                  : () => _confirmStatusUpdate('Fulfilled', 'Fulfill'),
              variant: ButtonVariant.outline,
              icon: LucideIcons.checkCheck,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Withdraw / Cancel Lot',
              onPressed: _isActionInProgress
                  ? null
                  : () => _confirmStatusUpdate('Cancelled', 'Cancel'),
              variant: ButtonVariant.outline,
              icon: LucideIcons.trash2,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'This lot is currently "${lot.status}". Status changes and price edits are closed.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildVolumePill(String label, String value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLabTestingCard(SellerCommodity lot) {
    final hasLabTesting =
        (lot.labName != null &&
            lot.labName!.toLowerCase().contains('riddhi siddhi')) ||
        _labRequest != null ||
        _isReportAvailable;

    if (!hasLabTesting) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quality & Assay Document',
                  style: AppTypography.titleMedium,
                ),
                const StatusBadge(status: 'Self-Declared'),
              ],
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              'Document Type',
              lot.labName ?? 'Visual Mandi Inspection',
            ),
            const SizedBox(height: 6),
            _buildInfoRow(
              'Certificate Reference',
              lot.labReportNumber ?? 'None',
            ),
          ],
        ),
      );
    }

    final isPaid =
        _labRequest?.isPaid == true ||
        _labStatus == 'Testing In Progress' ||
        _isReportAvailable;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.flaskConical,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Laboratory Testing & Report',
                    style: AppTypography.titleMedium,
                  ),
                ],
              ),
              if (_isReportAvailable)
                const StatusBadge(status: 'Report Available')
              else if (isPaid)
                const StatusBadge(status: 'Testing In Progress')
              else if (_labRequest?.paymentStatus ==
                  LabPaymentStatus.paymentPending)
                const StatusBadge(status: 'Pending')
              else
                const StatusBadge(status: 'Draft'),
            ],
          ),
          const SizedBox(height: 12),

          _buildInfoRow('Partner Laboratory', LabTestRateCard.laboratoryName),
          const SizedBox(height: 6),
          _buildInfoRow('Laboratory Location', 'Jaipur, Rajasthan'),
          const SizedBox(height: 6),
          if (_labRequest != null) ...[
            _buildInfoRow(
              'Requested Tests (${_labRequest!.selectedTests.length})',
              _labRequest!.selectedTests.map((t) => t.name).join(', '),
            ),
            const SizedBox(height: 6),
            _buildInfoRow(
              'Lab Testing Fee',
              '₹${_labRequest!.finalPayableAmount.toInt()} (UPI Confirmed)',
              isHighlight: true,
            ),
            const SizedBox(height: 6),
            _buildInfoRow('Transaction Ref', _labRequest!.transactionReference),
            const SizedBox(height: 6),
          ],

          if (_isReportAvailable) ...[
            const Divider(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.fileCheck,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verified Lab Certificate: ${_labReportNumber ?? "RSL-REPORT-VERIFIED"}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The certified laboratory assay report has been uploaded and authorized by Riddhi Siddhi Laboratory.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'View / Download Official Lab Report',
                    icon: LucideIcons.download,
                    variant: ButtonVariant.primary,
                    onPressed: () async {
                      if (_signedReportUrl != null &&
                          _signedReportUrl!.isNotEmpty) {
                        final uri = Uri.parse(_signedReportUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Opening report in browser...'),
                            ),
                          );
                        }
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Report file URL is currently being signed by backend.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            const Divider(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
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
                      Icon(LucideIcons.clock, size: 14, color: Colors.brown),
                      SizedBox(width: 6),
                      Text(
                        'Report Status: Testing in progress (Estimated 24-48 hrs)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.brown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sample submission protocol: Deliver 500g sealed representative sample to Riddhi Siddhi Laboratory, F-772 B, Road Number 6, VKI Area, Jaipur.',
                    style: TextStyle(fontSize: 10, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Row(
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
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
              fontSize: 12,
              color: isHighlight
                  ? AppColors.primary
                  : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }
}
