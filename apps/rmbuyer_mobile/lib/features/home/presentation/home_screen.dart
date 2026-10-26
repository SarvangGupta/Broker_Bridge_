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
import '../../search/data/search_repository.dart';
import '../../search/domain/search_model.dart';
import '../../search/presentation/widgets/broker_result_card.dart';
import '../../../l10n/app_localizations.dart';

/// Primary buyer dashboard home screen.
/// Implements mobile-first broker discovery, debounced commodity/broker search,
/// Post Requirement CTA, verified broker cards, and Counterparty Shield notices.
class HomeScreen extends StatefulWidget {
  final SearchRepository? searchRepository;
  final ContactLauncherService? contactLauncher;

  const HomeScreen({
    super.key,
    this.searchRepository,
    this.contactLauncher,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final SearchRepository _searchRepo;
  late final ContactLauncherService _contactLauncher;

  Timer? _debounceTimer;
  bool _isLoading = false;
  String? _errorMessage;
  List<SearchItem> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchRepo = widget.searchRepository ?? SearchRepository();
    _contactLauncher = widget.contactLauncher ?? ContactLauncherService();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
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
        child: SingleChildScrollView(
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

        // Fiduciary Disclaimer Banner
        Container(
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
                size: 18,
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
                      AppConfig.fiduciaryNoticeEn,
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
        ),
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
}
