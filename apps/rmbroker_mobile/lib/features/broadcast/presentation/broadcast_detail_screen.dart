import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/preferences/app_settings_provider.dart';
import '../domain/broadcast_history_models.dart';
import 'broadcast_history_screen.dart';

final broadcastDetailFutureProvider = FutureProvider.autoDispose.family<BroadcastHistoryItem?, String>((ref, id) async {
  final repo = ref.watch(broadcastHistoryRepositoryProvider);
  return repo.getBroadcastById(id);
});

class BroadcastDetailScreen extends ConsumerStatefulWidget {
  final String broadcastId;
  const BroadcastDetailScreen({super.key, required this.broadcastId});

  @override
  ConsumerState<BroadcastDetailScreen> createState() => _BroadcastDetailScreenState();
}

class _BroadcastDetailScreenState extends ConsumerState<BroadcastDetailScreen> {
  String _buyerSearch = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(appSettingsProvider);
    final detailAsync = ref.watch(broadcastDetailFutureProvider(widget.broadcastId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          settings.languagePref == AppLanguagePreference.hi
              ? 'प्रसारण विवरण'
              : 'Broadcast Details',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: settings.iconOnlyMode ? 'Show labels (*)' : 'Hide labels (*)',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: settings.iconOnlyMode
                    ? AppColors.primary
                    : AppColors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '*',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: settings.iconOnlyMode ? Colors.white : AppColors.primary,
                ),
              ),
            ),
            onPressed: () => ref.read(appSettingsProvider.notifier).toggleIconOnlyMode(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.alertTriangle, size: 40, color: AppColors.error),
                const SizedBox(height: 12),
                Text('Error: $err', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (item) {
          if (item == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.fileQuestion, size: 48, color: AppColors.textSecondaryLight),
                    const SizedBox(height: 16),
                    const Text('Broadcast not found or unauthorized access.', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to History')),
                  ],
                ),
              ),
            );
          }

          final filteredRecipients = item.recipients.where((r) {
            if (_buyerSearch.isEmpty) return true;
            final q = _buyerSearch.toLowerCase();
            return r.buyerName.toLowerCase().contains(q) || r.companyName.toLowerCase().contains(q);
          }).toList();

          final f = NumberFormat('#,##,###.##', 'en_IN');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Overview Header Card
                _buildOverviewCard(context, item, isDark),
                const SizedBox(height: 16),

                // 2. Immutable Price Snapshot Banner & Cards
                _buildSectionHeader(
                  title: 'Committed Price Snapshot',
                  icon: LucideIcons.shieldCheck,
                  subtitle: 'Immutable record sent at broadcast time. Independent of current seller listings.',
                ),
                const SizedBox(height: 10),

                ...item.priceSnapshots.map((offer) {
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    color: isDark ? AppColors.cardDark : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Grade: ${offer.gradeName} • ${offer.sellerCompanyName}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${f.format(offer.askingPrice)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    '/ ${offer.unitSymbol}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Revision v${offer.version}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Updated: ${DateFormat('dd MMM, hh:mm a').format(offer.priceUpdatedAt)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                              if (offer.location.isNotEmpty)
                                Text(
                                  offer.location,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // 3. Recipient-Level Details Section
                _buildSectionHeader(
                  title: 'Recipients & Delivery Outcomes (${item.recipients.length})',
                  icon: LucideIcons.users,
                  subtitle: 'Exact information and status communicated to each authorized buyer.',
                ),
                const SizedBox(height: 10),

                // Recipient Search
                if (item.recipients.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      onChanged: (v) => setState(() => _buyerSearch = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Filter recipients...',
                        prefixIcon: const Icon(LucideIcons.search, size: 16),
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ),

                ...filteredRecipients.map((recipient) {
                  return _buildRecipientCard(context, recipient, isDark);
                }),

                const SizedBox(height: 16),

                // 4. Sent Message Snapshot
                _buildSectionHeader(
                  title: 'Standard Message Text Snapshot',
                  icon: LucideIcons.messageSquare,
                  subtitle: 'Historical message copy delivered to recipient notifications.',
                ),
                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Exact Sent Message',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            icon: const Icon(LucideIcons.copy, size: 14),
                            label: const Text('Copy', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: item.fullMessage));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Message copied to clipboard')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        item.fullMessage,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context, BroadcastHistoryItem item, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      color: isDark ? AppColors.cardDark : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.id,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.brokerageName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                _buildStatusChip(item),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Dispatched Date',
                    value: item.formattedSentAt,
                    icon: LucideIcons.calendar,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Intended Buyers',
                    value: '${item.totalRecipients}',
                    icon: LucideIcons.users,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Successful Dispatches',
                    value: '${item.successfulCount}',
                    icon: LucideIcons.checkCircle2,
                    isDark: isDark,
                    color: AppColors.success,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Failed Dispatches',
                    value: '${item.failedCount}',
                    icon: LucideIcons.xCircle,
                    isDark: isDark,
                    color: item.failedCount > 0 ? AppColors.error : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color ?? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(BroadcastHistoryItem item) {
    if (item.hasFailure) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.errorBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertTriangle, size: 12, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              '${item.failedCount} Failed',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.checkCheck, size: 12, color: AppColors.success),
          SizedBox(width: 4),
          Text(
            'Delivered',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
        ),
      ],
    );
  }

  Widget _buildRecipientCard(
    BuildContext context,
    BroadcastRecipientDetail recipient,
    bool isDark,
  ) {
    Color statusColor;
    IconData statusIcon;

    switch (recipient.deliveryStatus) {
      case BroadcastDeliveryStatus.read:
        statusColor = AppColors.primary;
        statusIcon = LucideIcons.bookOpenCheck;
        break;
      case BroadcastDeliveryStatus.delivered:
        statusColor = AppColors.success;
        statusIcon = LucideIcons.checkCheck;
        break;
      case BroadcastDeliveryStatus.failed:
        statusColor = AppColors.error;
        statusIcon = LucideIcons.xCircle;
        break;
      case BroadcastDeliveryStatus.created:
      case BroadcastDeliveryStatus.sent:
        statusColor = const Color(0xFF0284C7);
        statusIcon = LucideIcons.send;
        break;
    }

    final f = NumberFormat('#,##,###.##', 'en_IN');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      color: isDark ? AppColors.cardDark : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                      Text(
                        recipient.buyerName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${recipient.companyName} • ${recipient.mobile}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        recipient.deliveryStatus.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (recipient.readAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(LucideIcons.eye, size: 11, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Read at ${DateFormat('hh:mm a, dd MMM').format(recipient.readAt!)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],

            if (recipient.failureReason != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertCircle, size: 12, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Failure: ${recipient.failureReason}',
                        style: const TextStyle(fontSize: 11, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            // Prices sent to this buyer
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Communicated Rates to this Buyer:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...recipient.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item.commodityName} (${item.gradeName})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '₹${f.format(item.price)} / ${item.unitSymbol} (v${item.version})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
