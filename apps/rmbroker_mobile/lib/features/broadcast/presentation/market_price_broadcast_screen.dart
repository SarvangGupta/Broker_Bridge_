import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/preferences/app_settings_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/market_broadcast_repository.dart';
import '../domain/market_broadcast_models.dart';

/// Provider for MarketBroadcastRepository.
final marketBroadcastRepositoryProvider =
    Provider<MarketBroadcastRepository>((ref) {
  return MarketBroadcastRepository();
});

/// Provider for loading associated buyers.
final broadcastBuyersProvider =
    FutureProvider.autoDispose<List<BuyerRecipient>>((ref) async {
  final repo = ref.watch(marketBroadcastRepositoryProvider);
  return repo.getAssociatedBuyers();
});

/// Provider for loading seller offers with latest-price resolution.
final broadcastOffersProvider =
    FutureProvider.autoDispose<List<SellerOfferPriceRevision>>((ref) async {
  final repo = ref.watch(marketBroadcastRepositoryProvider);
  return repo.getEligibleSellerOffers();
});

/// Interactive Market Price Broadcast Screen.
/// Guides the broker through buyer selection, offer selection,
/// authoritative same-day price revalidation, message preview, and in-app delivery.
class MarketPriceBroadcastScreen extends ConsumerStatefulWidget {
  const MarketPriceBroadcastScreen({super.key});

  @override
  ConsumerState<MarketPriceBroadcastScreen> createState() =>
      _MarketPriceBroadcastScreenState();
}

class _MarketPriceBroadcastScreenState
    extends ConsumerState<MarketPriceBroadcastScreen> {
  int _currentStep = 0; // 0 = Buyers, 1 = Offers, 2 = Preview, 3 = Sent

  // Selections
  final Set<String> _selectedBuyerUserIds = {};
  final Set<String> _selectedOfferIds = {};

  // Search queries
  String _buyerSearchQuery = '';
  String _offerSearchQuery = '';

  // Working state
  bool _isSending = false;
  bool _isValidating = false;
  String? _errorMessage;
  String? _stalePriceWarning;
  BroadcastOutcome? _outcome;

  String _brokerName = 'Authorized Broker Desk';
  String _brokerageName = 'Jaipur Commodity Trading Desk';

  @override
  void initState() {
    super.initState();
    _loadBrokerInfo();
  }

  Future<void> _loadBrokerInfo() async {
    final authRepo = AuthRepository();
    final broker = await authRepo.getCurrentBroker();
    if (broker != null && mounted) {
      setState(() {
        _brokerName = broker.fullName;
        _brokerageName = 'Jaipur Mandi Commodity Desk';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final isIconOnly = settings.iconOnlyMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Price Broadcast'),
        actions: [
          // Asterisk icon-only toggle
          IconButton(
            tooltip: isIconOnly ? 'Show labels (*)' : 'Hide labels (*)',
            icon: Text(
              '*',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isIconOnly ? AppColors.primary : AppColors.textSecondaryLight,
              ),
            ),
            onPressed: () =>
                ref.read(appSettingsProvider.notifier).toggleIconOnlyMode(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStepProgressIndicator(),
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildCurrentStepView()),
        ],
      ),
    );
  }

  Widget _buildStepProgressIndicator() {
    final steps = ['1. Buyers', '2. Offers', '3. Preview', '4. Sent'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.success
                      : (isActive ? AppColors.primary : const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : AppColors.textSecondaryLight,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                steps[index].substring(3),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive
                      ? AppColors.primary
                      : (isCompleted
                          ? AppColors.textPrimaryLight
                          : AppColors.textSecondaryLight),
                ),
              ),
              if (index < steps.length - 1) ...[
                const SizedBox(width: 6),
                const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.borderLight),
                const SizedBox(width: 6),
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildBuyerSelectionStep();
      case 1:
        return _buildOfferSelectionStep();
      case 2:
        return _buildPreviewStep();
      case 3:
        return _buildOutcomeStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ===========================================================================
  // STEP 1: BUYER SELECTION
  // ===========================================================================
  Widget _buildBuyerSelectionStep() {
    final buyersAsync = ref.watch(broadcastBuyersProvider);

    return buyersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertCircle, size: 40, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Unable to load associated buyers: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(broadcastBuyersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (buyers) {
        final filtered = buyers.where((b) {
          if (_buyerSearchQuery.isEmpty) return true;
          final q = _buyerSearchQuery.toLowerCase();
          return b.name.toLowerCase().contains(q) ||
              b.companyName.toLowerCase().contains(q) ||
              b.mobile.contains(q);
        }).toList();

        return Column(
          children: [
            // Search and Multi-Select Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search buyers by name, company, or mobile...',
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      suffixIcon: _buyerSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setState(() => _buyerSearchQuery = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (val) => setState(() => _buyerSearchQuery = val),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Selected: ${_selectedBuyerUserIds.length} of ${filtered.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedBuyerUserIds.addAll(filtered.map((b) => b.userId));
                              });
                            },
                            child: const Text('Select All', style: TextStyle(fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedBuyerUserIds.clear();
                              });
                            },
                            child: const Text('Clear', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Buyer List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(LucideIcons.users, size: 48, color: AppColors.textSecondaryLight),
                          SizedBox(height: 12),
                          Text(
                            'No associated buyers found',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Only active buyers explicitly linked to your broker desk are eligible.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final buyer = filtered[index];
                        final isSelected = _selectedBuyerUserIds.contains(buyer.userId);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: CheckboxListTile(
                              value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedBuyerUserIds.add(buyer.userId);
                                } else {
                                  _selectedBuyerUserIds.remove(buyer.userId);
                                }
                              });
                            },
                            activeColor: AppColors.primary,
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    buyer.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (buyer.isVerified)
                                  const Icon(
                                    LucideIcons.shieldCheck,
                                    size: 14,
                                    color: AppColors.success,
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  buyer.companyName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  buyer.mobile,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      },
                    ),
            ),

            // Bottom Action
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _selectedBuyerUserIds.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _errorMessage = null;
                          _currentStep = 1;
                        });
                      },
                icon: const Icon(LucideIcons.arrowRight, size: 18),
                label: Text(
                  'Continue to Select Offers (${_selectedBuyerUserIds.length} Buyers Selected)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // STEP 2: SELLER OFFER SELECTION WITH SAME-DAY LATEST-PRICE SELECTION
  // ===========================================================================
  Widget _buildOfferSelectionStep() {
    final offersAsync = ref.watch(broadcastOffersProvider);

    return offersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertCircle, size: 40, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Unable to load seller offers: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(broadcastOffersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (offers) {
        final filtered = offers.where((o) {
          if (_offerSearchQuery.isEmpty) return true;
          final q = _offerSearchQuery.toLowerCase();
          return o.commodityName.toLowerCase().contains(q) ||
              o.gradeName.toLowerCase().contains(q) ||
              o.sellerCompanyName.toLowerCase().contains(q) ||
              o.lotNumber.toLowerCase().contains(q);
        }).toList();

        final f = NumberFormat('#,##,###.##', 'en_IN');

        return Column(
          children: [
            // Search and Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search raw materials, grades, or sellers...',
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      suffixIcon: _offerSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setState(() => _offerSearchQuery = ''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => setState(() => _offerSearchQuery = val),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Selected: ${_selectedOfferIds.length} of ${filtered.length} listings',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedOfferIds.addAll(filtered.map((o) => o.offerId));
                              });
                            },
                            child: const Text('Select All', style: TextStyle(fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedOfferIds.clear();
                              });
                            },
                            child: const Text('Clear', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Offer List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(LucideIcons.layers, size: 48, color: AppColors.textSecondaryLight),
                          SizedBox(height: 12),
                          Text(
                            'No eligible seller offers available',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Only active, unexpired seller listings with valid prices are listed.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final offer = filtered[index];
                        final isSelected = _selectedOfferIds.contains(offer.offerId);
                        final dateStr = DateFormat('dd MMM, hh:mm a').format(offer.priceUpdatedAt);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: AppCard(
                            padding: const EdgeInsets.all(12),
                            child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedOfferIds.remove(offer.offerId);
                                } else {
                                  _selectedOfferIds.add(offer.offerId);
                                }
                              });
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedOfferIds.add(offer.offerId);
                                      } else {
                                        _selectedOfferIds.remove(offer.offerId);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${offer.commodityName} (${offer.gradeName})',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimaryLight,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryContainer.withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '₹${f.format(offer.askingPrice)}/${offer.unitSymbol}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Seller: ${offer.sellerCompanyName}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondaryLight,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Avail: ${f.format(offer.availableQuantity)} ${offer.unitSymbol}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textPrimaryLight,
                                            ),
                                          ),
                                          Text(
                                            'Updated: $dateStr (v${offer.version})',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                      },
                    ),
            ),

            // Bottom Navigation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(80, 48),
                      side: const BorderSide(color: AppColors.borderLight),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => setState(() => _currentStep = 0),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _selectedOfferIds.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _errorMessage = null;
                                _stalePriceWarning = null;
                                _currentStep = 2;
                              });
                            },
                      icon: const Icon(LucideIcons.fileText, size: 18),
                      label: Text(
                        'Generate Preview (${_selectedOfferIds.length} Offers)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // STEP 3: MESSAGE PREVIEW & MANDATORY PRICE REVALIDATION
  // ===========================================================================
  Widget _buildPreviewStep() {
    final buyersAsync = ref.watch(broadcastBuyersProvider);
    final offersAsync = ref.watch(broadcastOffersProvider);

    return buyersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (allBuyers) {
        return offersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (allOffers) {
            final selectedBuyers = allBuyers
                .where((b) => _selectedBuyerUserIds.contains(b.userId))
                .toList();

            final selectedOffers = allOffers
                .where((o) => _selectedOfferIds.contains(o.offerId))
                .toList();

            if (selectedOffers.isEmpty || selectedBuyers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Please select at least 1 buyer and 1 offer.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _currentStep = 0),
                      child: const Text('Back to Buyers'),
                    ),
                  ],
                ),
              );
            }

            final message = BroadcastDraft.buildStandardMessage(
              brokerageName: _brokerageName,
              brokerName: _brokerName,
              offers: selectedOffers,
            );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Stale Price Warning Banner if detected
                if (_stalePriceWarning != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.alertTriangle,
                            color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Price Update Detected!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _stalePriceWarning!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'The preview message below has been automatically updated with the latest verified price. Please review and reconfirm.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Audience & Scope Summary
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Icon(LucideIcons.users, color: AppColors.primary, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            '${selectedBuyers.length}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Authorized Buyers',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                      Container(height: 36, width: 1, color: AppColors.borderLight),
                      Column(
                        children: [
                          const Icon(LucideIcons.layers, color: AppColors.primary, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            '${selectedOffers.length}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Verified Offers',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                      Container(height: 36, width: 1, color: AppColors.borderLight),
                      Column(
                        children: [
                          const Icon(LucideIcons.shieldCheck, color: AppColors.success, size: 20),
                          const SizedBox(height: 4),
                          const Text(
                            'Latest Valid',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Price Revision',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Message Preview Card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Standardized Market Update Preview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    IconButton(
                      tooltip: 'Copy Message',
                      icon: const Icon(LucideIcons.copy, size: 16),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: message));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Message copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: SelectableText(
                    message,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Re-verify Freshness Button
                OutlinedButton.icon(
                  onPressed: _isValidating
                      ? null
                      : () async {
                          setState(() => _isValidating = true);
                          try {
                            final repo = ref.read(marketBroadcastRepositoryProvider);
                            final valRes = await repo.validatePriceSnapshot(selectedOffers);
                            if (mounted) {
                              setState(() {
                                _isValidating = false;
                                if (!valRes.isValid) {
                                  _stalePriceWarning = valRes.staleDescriptions.join('\n');
                                  ref.invalidate(broadcastOffersProvider);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('All seller prices verified up to date!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              });
                            }
                          } catch (e) {
                            if (mounted) setState(() => _isValidating = false);
                          }
                        },
                  icon: _isValidating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('Re-Verify Server Prices Before Send'),
                ),

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(80, 48),
                        side: const BorderSide(color: AppColors.borderLight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => setState(() => _currentStep = 1),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSending
                            ? null
                            : () => _executeSend(
                                  buyers: selectedBuyers,
                                  offers: selectedOffers,
                                  message: message,
                                ),
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(LucideIcons.send, size: 18),
                        label: Text(
                          _isSending ? 'Verifying & Sending...' : 'Confirm & Send Broadcast',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // STEP 4: SEND EXECUTION & OUTCOME
  // ===========================================================================
  Future<void> _executeSend({
    required List<BuyerRecipient> buyers,
    required List<SellerOfferPriceRevision> offers,
    required String message,
  }) async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final draft = BroadcastDraft(
      broadcastId: 'bc-${DateTime.now().millisecondsSinceEpoch}',
      brokerId: 'broker-active-session',
      brokerName: _brokerName,
      brokerageName: _brokerageName,
      recipients: buyers,
      offers: offers,
      generatedMessage: message,
      createdAt: DateTime.now(),
    );

    try {
      final repo = ref.read(marketBroadcastRepositoryProvider);
      final outcome = await repo.sendMarketPriceBroadcast(draft);

      if (mounted) {
        setState(() {
          _isSending = false;
          _outcome = outcome;
          _currentStep = 3;
        });
      }
    } on PriceDriftException catch (drift) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _stalePriceWarning = drift.details.join('\n');
          _errorMessage =
              'Price changed on server during confirmation. Refreshed preview to latest valid price. Please review and confirm again.';
        });
        ref.invalidate(broadcastOffersProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Widget _buildOutcomeStep() {
    final outcome = _outcome;
    if (outcome == null) {
      return const Center(child: Text('No broadcast outcome recorded'));
    }

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(outcome.sentAt);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: outcome.isFullSuccess
                  ? AppColors.successBackground
                  : AppColors.primaryContainer,
            ),
            child: Icon(
              outcome.isFullSuccess ? Icons.check_circle : LucideIcons.radio,
              color: outcome.isFullSuccess ? AppColors.success : AppColors.primary,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            outcome.isFullSuccess
                ? 'Market Price Broadcast Sent!'
                : 'Broadcast Processed',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Broadcast ID: ${outcome.broadcastId}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
          ),
        ),
        const SizedBox(height: 16),

        // Delivery Stats
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Delivery Status', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    outcome.isFullSuccess ? 'Delivered to In-App Inbox' : 'Partial Delivery',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: outcome.isFullSuccess ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Notified Associated Buyers', style: TextStyle(fontSize: 12)),
                  Text(
                    '${outcome.successfulDeliveryCount} of ${outcome.totalIntended}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Price Snapshot Timestamp', style: TextStyle(fontSize: 12)),
                  Text(
                    dateStr,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Listings Broadcasted', style: TextStyle(fontSize: 12)),
                  Text(
                    '${outcome.sentPriceSnapshot.length} Verified Offers',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Recipients list
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notified Associated Buyers',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...outcome.successfulRecipientNames.map(
                (name) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(name, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/work');
            }
          },
          child: const Text('Return to Broker Desk', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
