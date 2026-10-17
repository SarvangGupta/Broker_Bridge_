import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/features/directory/utils/phone_utils.dart';
import 'package:rmbroker_mobile/features/search/presentation/controllers/quick_dial_controller.dart';

/// Bottom sheet allowing the broker to choose an authorized counterparty
/// and initiate user-directed Call or WhatsApp communication.
class QuickCommunicationSheet extends ConsumerStatefulWidget {
  const QuickCommunicationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const QuickCommunicationSheet(),
    );
  }

  @override
  ConsumerState<QuickCommunicationSheet> createState() =>
      _QuickCommunicationSheetState();
}

class _QuickCommunicationSheetState
    extends ConsumerState<QuickCommunicationSheet> {
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quickDialAsync = ref.watch(quickDialContactsProvider);

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        LucideIcons.phoneCall,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Communication Desk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          'Speed-dial authorized counterparties',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Broker Mediation Firewall Banner (ADR-004)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: const [
                  Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All counterparty trade talks remain strictly broker-mediated. Zero direct buyer-seller negotiation permitted.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondaryLight,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Filter Search Bar
            TextField(
              controller: _filterController,
              onChanged: (val) {
                setState(() {
                  _filterQuery = val.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Filter counterparties by name or firm...',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.textDisabled),
                prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppColors.textSecondaryLight),
                filled: true,
                fillColor: AppColors.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Content Body
            Expanded(
              child: quickDialAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.alertCircle, size: 36, color: AppColors.error),
                      const SizedBox(height: 8),
                      const Text(
                        'Unable to load quick dial list',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(LucideIcons.users, size: 16),
                        label: const Text('Open Full Directory'),
                        onPressed: () {
                          Navigator.pop(context);
                          context.go('/directory');
                        },
                      ),
                    ],
                  ),
                ),
                data: (contacts) {
                  final filtered = contacts.where((c) {
                    if (_filterQuery.isEmpty) return true;
                    return c.name.toLowerCase().contains(_filterQuery) ||
                        c.companyName.toLowerCase().contains(_filterQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.userX, size: 36, color: AppColors.textDisabled),
                          const SizedBox(height: 8),
                          Text(
                            _filterQuery.isNotEmpty
                                ? 'No counterparty matching "$_filterQuery"'
                                : 'No speed-dial contacts available yet',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(LucideIcons.users, size: 16),
                            label: const Text('Go to Directory'),
                            onPressed: () {
                              Navigator.pop(context);
                              context.go('/directory');
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.borderLight),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isBuyer = item.isBuyer;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isBuyer
                              ? AppColors.primaryContainer.withValues(alpha: 0.4)
                              : AppColors.goldMuted.withValues(alpha: 0.25),
                          child: Text(
                            item.name.isNotEmpty ? item.name[0].toUpperCase() : 'C',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isBuyer ? AppColors.primaryDark : AppColors.goldDark,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: isBuyer
                                    ? AppColors.primaryContainer.withValues(alpha: 0.5)
                                    : AppColors.goldMuted.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.role.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: isBuyer ? AppColors.primaryDark : AppColors.goldDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          item.companyName,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(LucideIcons.phone, size: 18),
                              color: AppColors.primary,
                              tooltip: 'Open native dialler',
                              onPressed: () => PhoneUtils.launchCall(context, item.mobile),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.messageCircle, size: 18),
                              color: AppColors.success,
                              tooltip: 'Open WhatsApp',
                              onPressed: () => PhoneUtils.launchWhatsApp(context, item.mobile),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 8),
            // Footer Directory Action
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(LucideIcons.users, size: 16),
                label: const Text('Open Full Counterparty Directory'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/directory');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
