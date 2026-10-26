import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../authentication/data/auth_repository.dart';
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
  final CommoditiesRepository? commoditiesRepository;
  final SellerDealsRepository? dealsRepository;
  final SecureStorageService? storageService;

  const SellerHomeScreen({
    super.key,
    this.commoditiesRepository,
    this.dealsRepository,
    this.storageService,
  });

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  late final CommoditiesRepository _commoditiesRepository;
  late final SellerDealsRepository _dealsRepository;
  late final SecureStorageService _storage;

  bool _isLoading = true;
  String? _errorMessage;
  String _companyName = 'Bikaner Agro Traders';
  String _sellerName = 'Seller Desk';

  List<SellerCommodity> _activeLots = [];
  List<SellerDealModel> _activeDeals = [];

  @override
  void initState() {
    super.initState();
    _commoditiesRepository =
        widget.commoditiesRepository ?? CommoditiesRepository();
    _dealsRepository = widget.dealsRepository ?? SellerDealsRepository();
    _storage = widget.storageService ?? SecureStorageService();
    _loadDashboardData();
    CommoditiesRepository.commoditiesUpdatedNotifier.addListener(
      _onCommoditiesUpdated,
    );
  }

  @override
  void dispose() {
    CommoditiesRepository.commoditiesUpdatedNotifier.removeListener(
      _onCommoditiesUpdated,
    );
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
    final inNegotiationCount = _activeDeals
        .where((d) => d.status.toLowerCase().contains('negotiation'))
        .length;
    final bookedDealsCount = _activeDeals.length;
    final readyLotsCount = _activeLots
        .where((l) => l.loadingStatus == 'Ready to Load')
        .length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _companyName,
                    style: AppTypography.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  key: const Key('mediation_info_button'),
                  icon: const Icon(LucideIcons.info, size: 16),
                  tooltip: 'Mediation information',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  splashRadius: 16,
                  color: AppColors.primary,
                  onPressed: () => _showMediationDisclaimerDialog(context),
                ),
              ],
            ),
            Text(
              'Seller Desk • $_sellerName',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bell),
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(LucideIcons.search),
            tooltip: 'Search',
            onPressed: () => context.push('/search'),
          ),
          PopupMenuButton<String>(
            key: const Key('dashboard_overflow_menu_button'),
            icon: const Icon(LucideIcons.ellipsisVertical),
            tooltip: 'More options',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            onSelected: (value) => _handleOverflowMenuAction(context, value),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                key: Key('menu_item_profile'),
                value: 'profile',
                child: Row(
                  children: [
                    Icon(LucideIcons.user, size: 18, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text(
                      'My Profile',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                key: Key('menu_item_settings'),
                value: 'settings',
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.settings,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Settings',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                key: Key('menu_item_help'),
                value: 'help',
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.helpCircle,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Help & Support',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                key: Key('menu_item_notifications'),
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(LucideIcons.bell, size: 18, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text(
                      'Notifications',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                key: Key('menu_item_logout'),
                value: 'logout',
                child: Row(
                  children: [
                    Icon(LucideIcons.logOut, size: 18, color: AppColors.error),
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            _buildGreetingCard(context),
            const SizedBox(height: 12),

            // 4 Authoritative Metric Cards — single horizontal row
            _buildMetricsRow([
              _buildMetricCard(
                title: 'Active Lots',
                value: '$activeLotsCount',
                icon: LucideIcons.packageCheck,
                color: AppColors.primary,
                onTap: () => context.go('/commodities'),
              ),
              _buildMetricCard(
                title: 'In Negotiation',
                value: '$inNegotiationCount',
                icon: LucideIcons.handshake,
                color: AppColors.secondary,
                onTap: () => context.go('/deals'),
              ),
              _buildMetricCard(
                title: 'Booked Deals',
                value: '$bookedDealsCount',
                icon: LucideIcons.fileText,
                color: AppColors.success,
                onTap: () => context.go('/deals'),
              ),
              _buildMetricCard(
                title: 'Ready to Load',
                value: '$readyLotsCount',
                icon: LucideIcons.truck,
                color: AppColors.info,
                onTap: () => context.go('/commodities'),
              ),
            ]),
            const SizedBox(height: 20),

            // Commodity Lots Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'My Commodity Lots',
                    style: AppTypography.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.go('/commodities'),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(LucideIcons.chevronRight, size: 16),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (_activeLots.isEmpty)
              const AppEmptyState(
                title: 'No Active Commodity Lots',
                message: 'Post your first agricultural commodity lot to receive broker match proposals.',
              )
            else
              ..._activeLots
                  .take(3)
                  .map((lot) => _buildCommodityLotCard(context, lot)),

            const SizedBox(height: 20),

            // Recent Commercial Deals
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Recent Booked Contracts',
                    style: AppTypography.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
              ..._activeDeals
                  .take(2)
                  .map((deal) => _buildDealCard(context, deal)),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _handleOverflowMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'profile':
        context.go('/profile');
        break;
      case 'settings':
        context.push('/settings');
        break;
      case 'help':
        context.push('/help');
        break;
      case 'notifications':
        context.push('/notifications');
        break;
      case 'logout':
        _showSignOutDialog(context);
        break;
    }
  }

  Future<void> _showSignOutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of the RMSeller desk?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthRepository().signOut();
      AppRouter.authNotifier.setUnauthenticated();
    }
  }

  void _showMediationDisclaimerDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark
              ? AppColors.surfaceDark
              : AppColors.surfaceLight,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primaryContainer.withValues(alpha: 0.2)
                      : AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.shieldCheck,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mandi Mediation Active',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'All commodity negotiations and bookings are mediated through authorized mandi brokers. Buyer identities are shielded.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  Widget _buildGreetingCard(BuildContext context) {
    return Container(
      key: const Key('home_greeting_card'),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _companyName,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            key: const Key('home_post_commodity_button'),
            onPressed: () => context.push('/commodities/new'),
            icon: const Icon(LucideIcons.plusCircle, size: 16),
            label: const Text('Post Commodity'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lays the metric cards out in one equal-width row; falls back to
  /// horizontal scrolling only when each card would be narrower than 72px.
  Widget _buildMetricsRow(List<Widget> cards) {
    const gap = 8.0;
    const minCardWidth = 72.0;
    const cardHeight = 92.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - gap * (cards.length - 1);
        final fits = available / cards.length >= minCardWidth;
        final cardWidth = fits ? available / cards.length : minCardWidth;

        final row = Row(
          key: const Key('home_metrics_row'),
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(width: cardWidth, height: cardHeight, child: cards[i]),
            ],
          ],
        );

        return fits
            ? row
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: row,
              );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 14, color: color),
                  ),
                  const Spacer(),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: AppColors.textMutedLight,
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);

  Widget _buildLotMeta(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? AppColors.textMutedLight),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: color != null ? FontWeight.w700 : FontWeight.w600,
              color: color ?? AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommodityLotCard(BuildContext context, SellerCommodity lot) {
    final qty = lot.availableQuantity == lot.totalQuantity
        ? '${_formatQty(lot.totalQuantity)} ${lot.unit}'
        : '${_formatQty(lot.availableQuantity)} / ${_formatQty(lot.totalQuantity)} ${lot.unit}';
    final location = lot.mandiName?.isNotEmpty == true
        ? lot.mandiName!
        : '${lot.districtName}, ${lot.stateName}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        onTap: () => context.push('/commodities/${lot.id}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.wheat,
                size: 22,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          lot.commodityName,
                          style: AppTypography.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      StatusBadge(status: lot.status),
                    ],
                  ),
                  if (lot.gradeName.isNotEmpty)
                    Text(
                      lot.gradeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      _buildLotMeta(LucideIcons.package, qty),
                      _buildLotMeta(
                        LucideIcons.indianRupee,
                        '₹${lot.askingPrice.toStringAsFixed(0)} / ${lot.unit}',
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildLotMeta(LucideIcons.mapPin, location),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Lot ${lot.lotNumber}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedLight,
                        ),
                      ),
                      Text(
                        'Listed ${_timeAgo(lot.createdAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedLight,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          lot.loadingStatus,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.textMutedLight,
              ),
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
                color: AppColors.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.fileCheck2,
                size: 24,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deal.commodityName, style: AppTypography.titleSmall),
                  Text(
                    '${deal.agreedQuantity} ${deal.unit} @ ₹${deal.agreedPrice.toStringAsFixed(0)} • ${deal.brokerDeskName}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
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
