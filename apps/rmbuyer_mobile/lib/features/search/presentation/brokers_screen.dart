import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/search_repository.dart';
import '../domain/broker_model.dart';
import 'widgets/broker_result_card.dart';

/// Authorized mandi broker listing opened from the central Brokers tab.
/// Lists all verified broker desks with debounced name/mandi/commodity search.
class BrokersScreen extends StatefulWidget {
  final SearchRepository? searchRepository;
  final ContactLauncherService? contactLauncher;

  const BrokersScreen({super.key, this.searchRepository, this.contactLauncher});

  @override
  State<BrokersScreen> createState() => _BrokersScreenState();
}

class _BrokersScreenState extends State<BrokersScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final SearchRepository _searchRepo;
  late final ContactLauncherService _contactLauncher;

  Timer? _debounceTimer;
  List<BrokerModel> _brokers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchRepo = widget.searchRepository ?? SearchRepository();
    _contactLauncher = widget.contactLauncher ?? ContactLauncherService();
    _loadBrokers('');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBrokers(String query) async {
    setState(() => _isLoading = true);
    try {
      final brokers = await _searchRepo.searchBrokers(query: query);
      if (!mounted) return;
      setState(() {
        _brokers = brokers;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _brokers = query.isEmpty ? SearchRepository.fallbackBrokers : [];
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    setState(() {});
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadBrokers(query.trim());
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    _loadBrokers('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList.list(
                children: [
                  const Text(
                    'Brokers',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Find an authorized mandi broker for your procurement needs.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _searchController,
                    hint: 'Search broker by name, mandi or commodity',
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 18),
                            onPressed: _clearSearch,
                          )
                        : null,
                    onChanged: _onSearchChanged,
                    onSubmitted: (q) => _loadBrokers(q.trim()),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: AppLoadingIndicator(
                  message: 'Loading verified broker desks...',
                ),
              )
            else if (_brokers.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No authorized brokers currently listed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.separated(
                  itemCount: _brokers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => BrokerResultCard(
                    broker: _brokers[index],
                    contactLauncher: _contactLauncher,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
