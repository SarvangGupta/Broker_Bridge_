import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../commodities/data/commodities_repository.dart';
import '../../commodities/domain/commodity_model.dart';
import '../../deals/data/seller_deals_repository.dart';
import '../../deals/domain/seller_deal_model.dart';

class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({super.key});

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  final CommoditiesRepository _commoditiesRepository = CommoditiesRepository();
  final SellerDealsRepository _dealsRepository = SellerDealsRepository();
  final SecureStorageService _storage = SecureStorageService();

  bool _isLoading = true;
  String? _errorMessage;
  String _companyName = 'Bikaner Agro Traders';
  String _sellerName = 'Seller Desk';

  List<SellerCommodity> _activeLots = [];
  List<SellerDealModel> _activeDeals = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    CommoditiesRepository.commoditiesUpdatedNotifier.addListener(_onCommoditiesUpdated);
  }

  @override
  void dispose() {
    CommoditiesRepository.commoditiesUpdatedNotifier.removeListener(_onCommoditiesUpdated);
    super.dispose();
  }

  void _onCommoditiesUpdated() {
    if (mounted) _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final name = await _storage.getUserFullName();
      final company = await _storage.getCompanyName();

      final lots = await _commoditiesRepository.getCommodities();
      final deals = await _dealsRepository.getDeals();

      if (!mounted) return;

      setState(() {
        _sellerName = name ?? 'Seller Lead';
        _companyName = company ?? 'Commodity Enterprise';
        _activeLots = lots;
        _activeDeals = deals;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load dashboard metrics. ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppLoadingIndicator(message: 'Loading Seller Command Center...'),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seller Desk')),
        body: AppErrorState(
          message: _errorMessage!,
          onRetry: _loadDashboardData,
        ),
      );
    }

    final activeLotsCount = _activeLots.where((l) => l.isActive).length;
    final inNegotiationCount = _activeDeals.where((d) => d.status.toLowerCase().contains('negotiation')).length;
    final bookedDealsCount = _activeDeals.length;
    final readyLotsCount = _activeLots.where((l) => l.loadingStatus == 'Ready to Load').length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_companyName, style: AppTypography.titleMedium),
            Text(
              'Seller Desk • $_sellerName',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bell),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(LucideIcons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // P0 Action Required Banner / Fiduciary Alert
            _buildActionCenterCard(context),
            const SizedBox(height: 16),

            // 4 Authoritative Metric Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Active Lots',
                    value: '$activeLotsCount',
                    subtitle: 'Listed Supply',
                    icon: LucideIcons.packageCheck,
                    color: AppColors.primary,
                    onTap: () => context.go('/commodities'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'In Negotiation',
                    value: '$inNegotiationCount',
                    subtitle: 'Broker Rounds',
                    icon: LucideIcons.handshake,
                    color: AppColors.secondary,
                    onTap: () => context.go('/deals'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Booked Deals',
                    value: '$bookedDealsCount',
                    subtitle: 'Contracts Finalized',
                    icon: LucideIcons.fileText,
                    color: AppColors.success,
                    onTap: () => context.go('/deals'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Ready to Load',
                    value: '$readyLotsCount',
                    subtitle: 'Physical Stock',
                    icon: LucideIcons.truck,
                    color: AppColors.info,
                    onTap: () => context.go('/commodities'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Operational Actions
            Text('Quick Operations', style: AppTypography.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionBtn(
                    label: '+ Post Commodity',
                    icon: LucideIcons.plusCircle,
                    color: AppColors.primary,
                    onTap: () => context.push('/commodities/new'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildQuickActionBtn(
                    label: 'Discover Brokers',
                    icon: LucideIcons.users,
                    color: AppColors.secondary,
                    onTap: () => context.go('/brokers'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Commodity Listings Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Active Commodity Lots', style: AppTypography.titleMedium),
                TextButton(
                  onPressed: () => context.go('/commodities'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_activeLots.isEmpty)
              const AppEmptyState(
                title: 'No Active Commodity Lots',
                message: 'Post your first agricultural commodity lot to receive broker match proposals.',
              )
            else
              ..._activeLots.take(3).map((lot) => _buildCommodityLotCard(context, lot)),

            const SizedBox(height: 20),

            // Recent Commercial Deals
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Booked Contracts', style: AppTypography.titleMedium),
                TextButton(
                  onPressed: () => context.go('/deals'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_activeDeals.isEmpty)
              const AppEmptyState(
                title: 'No Active Deals',
                message: 'Deals will appear here when brokers match buyer demand with your supply lots.',
              )
            else
              ..._activeDeals.take(2).map((deal) => _buildDealCard(context, deal)),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCenterCard(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.primaryContainer.withOpacity(0.5),
      borderColor: AppColors.primary.withOpacity(0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.shieldCheck, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mandi Mediation Active',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'All commodity negotiations and bookings are mediated through authorized mandi brokers. Buyer identities are shielded.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTypography.displayLarge.copyWith(fontSize: 26, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildCommodityLotCard(BuildContext context, SellerCommodity lot) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => context.push('/commodities/${lot.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lot.commodityName, style: AppTypography.titleSmall),
                      Text(lot.gradeName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
                StatusBadge(status: lot.status),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available Supply', style: TextStyle(fontSize: 11, color: AppColors.textMutedLight)),
                    Text(
                      '${lot.availableQuantity} / ${lot.totalQuantity} ${lot.unit}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Asking Price', style: TextStyle(fontSize: 11, color: AppColors.textMutedLight)),
                    Text(
                      '₹${lot.askingPrice.toStringAsFixed(0)} / ${lot.unit}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.mapPin, size: 13, color: AppColors.textMutedLight),
                const SizedBox(width: 4),
                Text('${lot.districtName}, ${lot.stateName}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(lot.loadingStatus, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealCard(BuildContext context, SellerDealModel deal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => context.push('/deals/${deal.id}'),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.fileCheck2, size: 24, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deal.commodityName, style: AppTypography.titleSmall),
                  Text(
                    '${deal.agreedQuantity} ${deal.unit} @ ₹${deal.agreedPrice.toStringAsFixed(0)} • ${deal.brokerDeskName}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
            StatusBadge(status: deal.status),
          ],
        ),
      ),
    );
  }
}
