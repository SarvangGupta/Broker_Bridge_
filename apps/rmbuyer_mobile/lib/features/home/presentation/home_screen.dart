import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../offers/data/offers_repository.dart';
import '../../requirements/data/requirements_repository.dart';
import '../../requirements/domain/requirement_model.dart';
import '../../search/data/search_repository.dart';
import '../../search/domain/search_model.dart';
import '../../search/presentation/widgets/broker_result_card.dart';
import '../../../l10n/app_localizations.dart';

/// Primary buyer dashboard home screen.
/// Implements mobile-first broker discovery, debounced commodity/broker search,
/// Post Requirement CTA, verified broker cards, current buyer requirements summary,
/// and Counterparty Shield notices.
class HomeScreen extends StatefulWidget {
  final SearchRepository? searchRepository;
  final ContactLauncherService? contactLauncher;
  final RequirementsRepository? requirementsRepository;
  final OffersRepository? offersRepository;

  const HomeScreen({
    super.key,
    this.searchRepository,
    this.contactLauncher,
    this.requirementsRepository,
    this.offersRepository,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final SearchRepository _searchRepo;
  late final ContactLauncherService _contactLauncher;
  late final RequirementsRepository _requirementsRepo;
  late final OffersRepository _offersRepo;

  Timer? _debounceTimer;
  bool _isLoading = false;
  String? _errorMessage;
  List<SearchItem> _searchResults = [];
  bool _isSearching = false;

  List<BuyerRequirement> _requirements = [];
  Map<String, int> _offerCounts = {};
  bool _isRequirementsLoading = true;
  String? _requirementsError;

  @override
  void initState() {
    super.initState();
    _searchRepo = widget.searchRepository ?? SearchRepository();
    _contactLauncher = widget.contactLauncher ?? ContactLauncherService();
    _requirementsRepo = widget.requirementsRepository ?? RequirementsRepository();
    _offersRepo = widget.offersRepository ?? OffersRepository();
    RequirementsRepository.requirementsUpdatedNotifier.addListener(_loadRequirements);
    _loadRequirements();
  }

  @override
  void dispose() {
    RequirementsRepository.requirementsUpdatedNotifier.removeListener(_loadRequirements);
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequirements() async {
    if (!mounted) return;
    setState(() {
      _isRequirementsLoading = true;
      _requirementsError = null;
    });

    try {
      final reqs = await _requirementsRepo.getRequirements(
        statusFilter: 'ALL',
        includeBaseline: false,
      );

      final Map<String, int> counts = {};
      try {
        final offers = await _offersRepo.getOffers();
        for (final offer in offers) {
          if (offer.requirementId.isNotEmpty) {
            counts[offer.requirementId] = (counts[offer.requirementId] ?? 0) + 1;
          }
        }
      } catch (e) {
        debugPrint('Offers count load note: $e');
      }

      if (!mounted) return;
      setState(() {
        _requirements = reqs;
        _offerCounts = counts;
        _isRequirementsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _requirementsError = 'Unable to load requirements. Please check your connection.';
        _isRequirementsLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim();

    if (clean.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoading = true;
      _errorMessage = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(clean);
    });
  }

  Future<void> _executeSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    try {
      final results = await _searchRepo.search(query: clean);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to complete search. Please verify your connection.';
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults = [];
      _errorMessage = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (_isSearching) {
              await _executeSearch(_searchController.text);
            } else {
              await _loadRequirements();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar: RMBuyer Branding, Profile Shortcut & Notification Bell
                _buildHeader(context),
                const SizedBox(height: 18),

                // Primary Search Field: "Search commodity or broker"
                AppTextField(
                  controller: _searchController,
                  hint: context.tr(Tr.homeSearchHint),
                  prefixIcon: const Icon(LucideIcons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: _clearSearch,
                        )
                      : null,
                  onChanged: _onSearchChanged,
                  onSubmitted: _executeSearch,
                ),
                const SizedBox(height: 18),

                // Conditional Display: Live Search Results vs Default Home Experience
                if (_isSearching)
                  _buildSearchResults(context)
                else
                  _buildDefaultHomeContent(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'RB',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppConfig.appName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryLight,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  context.tr(Tr.homeSubtitle),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // Notifications Shortcut
            IconButton(
              icon: const Icon(LucideIcons.bell),
              color: AppColors.textPrimaryLight,
              tooltip: context.tr(Tr.tooltipNotifications),
              onPressed: () => context.push('/notifications'),
            ),
            // Profile & Settings
            InkWell(
              key: const Key('home-profile-settings'),
              onTap: () => context.push('/settings'),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.user,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: AppLoadingIndicator(message: 'Searching commodities and brokers...'),
      );
    }

    if (_errorMessage != null) {
      return AppErrorState(
        message: _errorMessage!,
        onRetry: () => _executeSearch(_searchController.text),
      );
    }

    if (_searchResults.isEmpty) {
      return AppEmptyState(
        title: 'No matching broker found.',
        description:
            'Cannot find "${_searchController.text}"? Post your requirement directly to broadcast to licensed mandi brokers across India.',
        icon: LucideIcons.searchX,
        actionLabel: 'Post Your Requirement',
        onAction: () => context.push('/requirements/new'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Search Results (${_searchResults.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _clearSearch,
              child: const Text('Back to Home', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchResults.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _searchResults[index];
            if (item.isBroker && item.broker != null) {
              return BrokerResultCard(
                broker: item.broker!,
                contactLauncher: _contactLauncher,
              );
            }

            // Commodity search result item
            return AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: () {
                context.push(
                  '/requirements/new?commodity=${Uri.encodeComponent(item.title)}',
                );
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.package,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppColors.textMutedLight,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDefaultHomeContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary CTA: Post Your Requirement Banner
        AppCard(
          color: AppColors.primary,
          border: Border.all(color: AppColors.primaryDark),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.plus,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Need Commodity Supply?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Post your target quantity, specifications, and price to receive verified quotes from licensed mandi brokers.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCFD8DC),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Post Your Requirement',
                onPressed: () => context.push('/requirements/new'),
                variant: AppButtonVariant.secondary,
                icon: LucideIcons.filePlus,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Section: Your Current Requirements
        _buildCurrentRequirementsSection(context),
        const SizedBox(height: 14),

        // Protected Broker-mediated procurement banner
        _buildProcurementShieldBanner(),
        const SizedBox(height: 16),

        // Quick Access: Broker Offers & Negotiation (Sprint RB-BUYER-05)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onTap: () => context.push('/offers'),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.badgePercent,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Broker Offers & Negotiation',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Review proposals, submit counter-offers, and track terms.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildCurrentRequirementsSection(BuildContext context) {
    if (_isRequirementsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (_requirementsError != null) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 24),
            const SizedBox(height: 8),
            Text(
              _requirementsError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              key: const Key('home-requirements-retry-btn'),
              onPressed: _loadRequirements,
              icon: const Icon(LucideIcons.rotateCw, size: 14),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      );
    }

    final activeCount = _requirements.where((r) {
      final s = r.status.toLowerCase();
      return s == 'open' || s == 'active' || s == 'matching' || s.contains('negotiat');
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.clipboardList,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Your Current Requirements',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      if (activeCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$activeCount ACTIVE',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2E7D32),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Track your requirements and broker responses.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              key: const Key('home-view-all-requirements'),
              onTap: () => context.go('/requirements'),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(LucideIcons.chevronRight, size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // List or Empty State
        if (_requirements.isEmpty)
          _buildEmptyRequirementsCard(context)
        else ...[
          for (final req in _requirements.take(5)) ...[
            _buildRequirementCard(req, _offerCounts[req.id] ?? 0),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 2),
          // Create another requirement button
          OutlinedButton.icon(
            key: const Key('home-create-requirement-btn'),
            onPressed: () => context.push('/requirements/new'),
            icon: const Icon(LucideIcons.plus, size: 15),
            label: const Text(
              'Create another requirement',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyRequirementsCard(BuildContext context) {
    return AppCard(
      key: const Key('home-requirements-empty'),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.clipboardList,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Current Requirements',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'You have no active requirements. Post your raw material target to receive quotes from licensed mandi brokers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            key: const Key('home-empty-post-requirement-btn'),
            onPressed: () => context.push('/requirements/new'),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Post Your Requirement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementCard(BuyerRequirement req, int offerCount) {
    final isDraft = req.status.trim().toLowerCase() == 'draft';
    final quantityStr = req.quantity % 1 == 0
        ? req.quantity.toInt().toString()
        : req.quantity.toString();
    final deliveryLoc = req.deliveryTerms != null && req.deliveryTerms!.trim().isNotEmpty
        ? req.deliveryTerms!.trim()
        : null;

    return AppCard(
      key: Key('home-req-card-${req.id}'),
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/requirements/${req.id}', extra: req),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CommodityThumbnail(commodityName: req.commodityName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Commodity Name + Status Badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        req.commodityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusBadge(req.status),
                  ],
                ),
                const SizedBox(height: 5),

                // Row 2: Quantity + Delivery Location
                Row(
                  children: [
                    const Icon(LucideIcons.package, size: 13, color: AppColors.textMutedLight),
                    const SizedBox(width: 4),
                    Text(
                      '$quantityStr ${req.unit}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    if (deliveryLoc != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '|',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMutedLight.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      const Icon(LucideIcons.mapPin, size: 13, color: AppColors.textMutedLight),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          deliveryLoc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),

                // Row 3: Broker offer count / response info
                Row(
                  children: [
                    Icon(
                      isDraft ? LucideIcons.fileText : LucideIcons.users,
                      size: 13,
                      color: isDraft ? AppColors.warning : AppColors.textMutedLight,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        isDraft
                            ? 'Complete details to publish'
                            : offerCount > 0
                                ? '$offerCount broker offer${offerCount == 1 ? '' : 's'} · Awaiting response'
                                : 'Awaiting response',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDraft ? AppColors.warning : AppColors.textSecondaryLight,
                          fontWeight: isDraft ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: AppColors.textMutedLight,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final s = status.trim().toLowerCase();
    Color bg;
    Color fg;
    String label;

    if (s == 'draft') {
      bg = AppColors.warningBackground;
      fg = AppColors.warning;
      label = 'Draft';
    } else if (s == 'open' || s == 'active' || s == 'matching') {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
      label = 'Active';
    } else if (s.contains('negotiat')) {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
      label = 'In Negotiation';
    } else if (s.contains('fulfil') || s.contains('complet') || s.contains('closed')) {
      bg = const Color(0xFFE3F2FD);
      fg = const Color(0xFF1565C0);
      label = 'Completed';
    } else if (s.contains('cancel') || s.contains('reject')) {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
      label = 'Cancelled';
    } else {
      bg = AppColors.borderLight;
      fg = AppColors.textSecondaryLight;
      label = status;
    }

    return Container(
      key: Key('home-req-status-$s'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcurementShieldBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.shieldCheck,
            size: 20,
            color: AppColors.primary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Regulated Broker-Mediated Procurement',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'All offers and negotiations stay with your selected brokers.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryDark,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommodityThumbnail extends StatelessWidget {
  final String commodityName;

  const _CommodityThumbnail({required this.commodityName});

  @override
  Widget build(BuildContext context) {
    final lower = commodityName.toLowerCase();
    Color bgColor;
    Color iconColor;
    IconData icon;

    if (lower.contains('maize') || lower.contains('corn')) {
      bgColor = const Color(0xFFFFF8E1);
      iconColor = const Color(0xFFF57F17);
      icon = LucideIcons.wheat;
    } else if (lower.contains('mustard')) {
      bgColor = const Color(0xFFFFFDE7);
      iconColor = const Color(0xFFFBC02D);
      icon = LucideIcons.flower2;
    } else if (lower.contains('rice') || lower.contains('paddy') || lower.contains('bran')) {
      bgColor = const Color(0xFFE8F5E9);
      iconColor = const Color(0xFF388E3C);
      icon = LucideIcons.sprout;
    } else if (lower.contains('wheat') ||
        lower.contains('chana') ||
        lower.contains('gram') ||
        lower.contains('soybean') ||
        lower.contains('soya')) {
      bgColor = const Color(0xFFEFEBE9);
      iconColor = const Color(0xFF6D4C41);
      icon = LucideIcons.wheat;
    } else {
      bgColor = AppColors.primaryContainer;
      iconColor = AppColors.primary;
      icon = LucideIcons.package;
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 26,
          color: iconColor,
        ),
      ),
    );
  }
}
