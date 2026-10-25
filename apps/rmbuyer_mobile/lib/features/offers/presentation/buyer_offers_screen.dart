import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/offers_repository.dart';
import '../domain/buyer_offer_model.dart';
import 'offer_details_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Screen displaying broker-provided commercial offers and negotiation statuses for the buyer.
/// Strict Counterparty Shield: All offers remain strictly broker-mediated; zero seller details are surfaced.
class BuyerOffersScreen extends StatefulWidget {
  final String? initialRequirementId;
  final OffersRepository? repository;

  const BuyerOffersScreen({
    super.key,
    this.initialRequirementId,
    this.repository,
  });

  @override
  State<BuyerOffersScreen> createState() => _BuyerOffersScreenState();
}

class _BuyerOffersScreenState extends State<BuyerOffersScreen> {
  late final OffersRepository _repo;
  String _selectedStatus = 'ALL';
  bool _isLoading = true;
  String? _errorMessage;
  List<BuyerOffer> _offers = [];

  final List<String> _statusFilters = [
    'ALL',
    'Proposed',
    'Countered',
    'Accepted',
    'Rejected',
    'Expired',
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? OffersRepository();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _repo.getOffers(
        requirementId: widget.initialRequirementId,
        statusFilter: _selectedStatus,
      );
      if (!mounted) return;
      setState(() {
        _offers = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load broker proposals. Please verify your connection.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(Tr.titleOffers)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCw),
            tooltip: 'Refresh',
            onPressed: _loadOffers,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Counterparty Shield Security Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.primaryContainer.withValues(alpha: 0.6),
              child: const Row(
                children: [
                  Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Counterparty Shield: All commercial offers are mediated by licensed brokers. Direct counterparty contacts remain confidential.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Status Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceLight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statusFilters.map((s) {
                    final isSelected = _selectedStatus == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s == 'ALL' ? 'All Offers' : s),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedStatus = s;
                            });
                            _loadOffers();
                          }
                        },
                        selectedColor: AppColors.primaryContainer,
                        backgroundColor: AppColors.surfaceLight,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.primaryDark : AppColors.textSecondaryLight,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.borderLight,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(),

            // Offers List / States
            Expanded(
              child: _buildOffersList(currencyFormat),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersList(NumberFormat currencyFormat) {
    if (_isLoading) {
      return const AppLoadingIndicator(
        message: 'Retrieving commercial broker offers and proposals...',
      );
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        onRetry: _loadOffers,
      );
    }

    if (_offers.isEmpty) {
      return AppEmptyState(
        title: 'No Broker Offers Found',
        description: _selectedStatus == 'ALL'
            ? 'Your requirements currently have no active broker offers. Once brokers source matching lots, proposals will appear here.'
            : 'No offers currently matching "$_selectedStatus" status.',
        icon: LucideIcons.badgePercent,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _offers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final offer = _offers[index];

        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Commodity & Status Badge Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.commodityName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          offer.gradeName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    status: offer.status,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Requirement Reference Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  'Requirement: ${offer.requirementDisplayId}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Commercial Pricing & Volume Metrics
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Offered Rate',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${currencyFormat.format(offer.offeredPrice)} / ${offer.unit}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Offered Quantity',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${offer.offeredQuantity} ${offer.unit}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Total Value',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currencyFormat.format(offer.totalEstimatedValue),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Broker Desk & Expiry Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.briefcase, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        offer.brokerName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  if (offer.validUntil != null)
                    Row(
                      children: [
                        Icon(
                          LucideIcons.clock,
                          size: 13,
                          color: offer.isExpired ? AppColors.error : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          offer.isExpired
                              ? 'Expired'
                              : 'Valid till ${DateFormat('dd MMM').format(offer.validUntil!)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: offer.isExpired ? AppColors.error : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Action CTA Button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: offer.isActionable ? 'Review & Negotiate' : 'View Proposal Terms',
                  icon: LucideIcons.arrowRight,
                  variant: offer.isActionable ? AppButtonVariant.primary : AppButtonVariant.outline,
                  onPressed: () {
                    try {
                      context.push('/offers/${offer.id}', extra: offer);
                    } catch (_) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OfferDetailsScreen(
                            offerId: offer.id,
                            initialOffer: offer,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
