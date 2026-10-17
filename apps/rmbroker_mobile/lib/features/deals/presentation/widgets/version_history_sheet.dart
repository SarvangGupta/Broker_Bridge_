import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../controllers/deal_detail_controller.dart';

/// Modal bottom sheet displaying the complete chronological audit timeline of deal term versions.
/// Visualizes immutable versions, change reasons, timestamps, and material field diffs.
class VersionHistorySheet extends ConsumerWidget {
  final String dealId;
  final String dealRef;

  const VersionHistorySheet({
    super.key,
    required this.dealId,
    required this.dealRef,
  });

  static Future<void> show(
    BuildContext context, {
    required String dealId,
    required String dealRef,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VersionHistorySheet(
        dealId: dealId,
        dealRef: dealRef,
      ),
    );
  }

  Color _getStatusBadgeColor(String status) {
    final clean = status.toLowerCase();
    if (clean.contains('finalized')) return AppColors.success;
    if (clean.contains('superseded')) return AppColors.textSecondaryLight;
    if (clean.contains('ready')) return AppColors.primary;
    if (clean.contains('awaiting')) return const Color(0xFF7C3AED);
    if (clean.contains('negotiation')) return const Color(0xFFD97706);
    return AppColors.textSecondaryLight;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dealDetailProvider(dealId));
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.history, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Terms Version History',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Immutable audit log of contract terms for $dealRef',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            // Timeline Content
            Expanded(
              child: state.isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : state.versionHistory.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.fileClock, size: 40, color: AppColors.textSecondaryLight),
                                const SizedBox(height: 10),
                                const Text(
                                  'Version 1 Active',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Current contract terms are at baseline Version 1. Any negotiated revisions will create immutable sequential versions.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: state.versionHistory.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final ver = state.versionHistory[index];
                            final statusColor = _getStatusBadgeColor(ver.status);
                            final isLatest = index == 0;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isLatest
                                    ? AppColors.primary.withValues(alpha: 0.03)
                                    : AppColors.backgroundLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isLatest ? AppColors.primary.withValues(alpha: 0.3) : AppColors.borderLight,
                                  width: isLatest ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isLatest ? AppColors.primary : AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(6),
                                          border: isLatest ? null : Border.all(color: AppColors.borderLight),
                                        ),
                                        child: Text(
                                          'Version ${ver.versionNumber}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: isLatest ? Colors.white : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          ver.status,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        dateFormat.format(ver.createdAt),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Actor provenance
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.userCheck, size: 13, color: AppColors.textSecondaryLight),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Actor: ${ver.actorName} (${ver.actorRole})',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                      ),
                                    ],
                                  ),

                                  // Reason for amendment
                                  if (ver.changeReason != null && ver.changeReason!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceLight,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.borderLight),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(LucideIcons.messageSquare, size: 12, color: AppColors.primary),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Reason: ${ver.changeReason}',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w500,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Material Diffs
                                  if (ver.diffs.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Changes Applied in this Version:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: ver.diffs.map((diff) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceLight,
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(color: AppColors.borderLight),
                                          ),
                                          child: Text(
                                            '${diff.label}: ${diff.oldValue ?? "None"} → ${diff.newValue}',
                                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
