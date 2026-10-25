import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../domain/directory_contact.dart';
import '../domain/directory_state.dart';
import 'controllers/directory_controller.dart';
import 'widgets/contact_details_sheet.dart';
import 'widgets/contact_form_modal.dart';
import 'widgets/directory_contact_card.dart';
import 'widgets/directory_search_filter_bar.dart';

/// Buyer & Seller Directory screen for the RMBroker workstation.
class DirectoryScreen extends ConsumerWidget {
  const DirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directoryControllerProvider);
    final controller = ref.read(directoryControllerProvider.notifier);

    final defaultRole = state.activeTab == 'seller' ? ContactRole.seller : ContactRole.buyer;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Directory',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              '(Buyers & Sellers)',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('directory_refresh_button'),
            icon: const Icon(LucideIcons.refreshCw, size: 18, color: Colors.white),
            tooltip: 'Refresh Directory',
            onPressed: () => controller.loadContacts(isRefresh: true),
          ),
          IconButton(
            key: const Key('directory_add_contact_button'),
            icon: const Icon(LucideIcons.userPlus, size: 20, color: Colors.white),
            tooltip: 'Add Contact',
            onPressed: () => _addContact(context, defaultRole),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_contact_fab'),
        onPressed: () => _addContact(context, defaultRole),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.userPlus, size: 18),
        label: Text(
          state.activeTab == 'seller' ? 'Add Seller' : (state.activeTab == 'buyer' ? 'Add Buyer' : 'Add Contact'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      body: Column(
        children: [
          // 1. Search & role tabs
          DirectorySearchFilterBar(
            activeTab: state.activeTab,
            searchQuery: state.searchQuery,
            statusFilter: state.statusFilter,
            stats: state.stats,
            onTabChanged: controller.setActiveTab,
            onSearchChanged: controller.setSearchQuery,
            onClearSearch: controller.clearSearch,
            onStatusFilterChanged: controller.setStatusFilter,
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // 2. Main Body Content based on status
          Expanded(
            child: _buildBodyContent(context, state, controller),
          ),
        ],
      ),
    );
  }

  Future<void> _addContact(BuildContext context, ContactRole defaultRole) async {
    final added = await ContactFormModal.show(
      context,
      defaultRole: defaultRole,
    );
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Counterparty successfully registered in directory.'),
          backgroundColor: Color(0xFF0D9488),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildBodyContent(
    BuildContext context,
    DirectoryState state,
    DirectoryController controller,
  ) {
    switch (state.status) {
      case DirectoryStatus.initial:
      case DirectoryStatus.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryNavy),
              SizedBox(height: 16),
              Text(
                'Loading authorized counterparties...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );

      case DirectoryStatus.unavailable:
        return _buildUnavailableState(context, state, controller);

      case DirectoryStatus.error:
        return _buildErrorState(context, state, controller);

      case DirectoryStatus.loaded:
        final contacts = state.filteredContacts;
        if (contacts.isEmpty && !state.hasMore) {
          return _buildEmptyState(context, state, controller);
        }

        // A footer row while more pages exist: it loads the next page when it
        // scrolls into view (or shows a retry if that page failed).
        final showFooter = state.hasMore || state.loadMoreError != null;
        return RefreshIndicator(
          onRefresh: () => controller.loadContacts(isRefresh: true),
          color: AppColors.primaryNavy,
          child: ListView.separated(
            // Bottom padding keeps the last row clear of the Add Contact button.
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: contacts.length + (showFooter ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.borderLight),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemBuilder: (ctx, i) {
              if (i == contacts.length) {
                return _buildLoadMoreFooter(state, controller);
              }
              final contact = contacts[i];
              return DirectoryContactCard(
                key: Key('contact_card_${contact.id}'),
                contact: contact,
                onTap: () => ContactDetailsSheet.show(ctx, contact),
              );
            },
          ),
        );
    }
  }

  Widget _buildLoadMoreFooter(DirectoryState state, DirectoryController controller) {
    if (state.loadMoreError != null && !state.isLoadingMore) {
      return Padding(
        key: const Key('directory_load_more_error'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Text(
              state.loadMoreError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: controller.loadMore,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (!state.isLoadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadMore());
    }
    return const Padding(
      key: Key('directory_load_more'),
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primaryNavy),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    DirectoryState state,
    DirectoryController controller,
  ) {
    String title = 'No Counterparties Found';
    String description =
        'No verified buyers or sellers currently match your filter criteria.';

    if (state.searchQuery.isNotEmpty) {
      title = 'No Search Results';
      description =
          'No contacts match "${state.searchQuery}". Try searching with a different name, mandi, or mobile number.';
    } else if (state.activeTab == 'buyer') {
      title = 'No Buyers Registered';
      description =
          'Your broker desk does not have any buyers assigned yet. Tap "Add Buyer" to register your first counterparty.';
    } else if (state.activeTab == 'seller') {
      title = 'No Sellers Registered';
      description =
          'Your broker desk does not have any sellers assigned yet. Tap "Add Seller" to register commodity suppliers.';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: AppEmptyState(
              icon: LucideIcons.users,
              title: title,
              description: description,
              actionLabel: (state.searchQuery.isNotEmpty || state.statusFilter != 'all')
                  ? 'Reset Filters'
                  : 'Add Counterparty',
              onAction: (state.searchQuery.isNotEmpty || state.statusFilter != 'all')
                  ? () {
                      controller.clearSearch();
                      controller.setStatusFilter('all');
                    }
                  : () {
                      ContactFormModal.show(
                        context,
                        defaultRole: state.activeTab == 'seller'
                            ? ContactRole.seller
                            : ContactRole.buyer,
                      );
                    },
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnavailableState(
    BuildContext context,
    DirectoryState state,
    DirectoryController controller,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Icon(
                LucideIcons.fileQuestion,
                size: 36,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Directory Contract Pending',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.contractNotice ??
                  'The authoritative REST endpoint /api/v1/broker/directory is pending backend exposure. Direct database connection requires an authenticated broker session.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => controller.loadContacts(),
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    DirectoryState state,
    DirectoryController controller,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Icon(
                LucideIcons.alertCircle,
                size: 36,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Directory',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ??
                  'Unable to establish a secure connection to the counterparty directory. Please verify network access.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => controller.loadContacts(),
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
