import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/contact_launcher_service.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/broker_model.dart';

/// Placeholder values the broker model substitutes when data is missing;
/// they carry no information, so directory and profile views hide them.
const _placeholderLocation = 'Mandi Trading Floor';

/// Real broker location, or null when only the model's placeholder is present.
String? brokerDisplayLocation(BrokerModel broker) {
  final loc = broker.location?.trim();
  if (loc == null || loc.isEmpty || loc == _placeholderLocation) return null;
  return loc;
}

/// Compact, fully tappable directory card for an authorized broker.
/// Contact actions live on the broker profile, never on the card.
/// Strictly enforces Counterparty Shield: seller identities are never rendered.
class BrokerResultCard extends StatelessWidget {
  final BrokerModel broker;

  /// Retained for call-site compatibility; contact now happens on the profile.
  final ContactLauncherService? contactLauncher;
  final VoidCallback? onTap;

  static const int _maxChips = 4;

  const BrokerResultCard({
    super.key,
    required this.broker,
    this.contactLauncher,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final location = brokerDisplayLocation(broker);
    final commodities = broker.commoditiesHandled;
    final extra = commodities.length - _maxChips;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      onTap: onTap ?? () => context.push('/brokers/${broker.id}', extra: broker),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.briefcase,
              size: 22,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        broker.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TrustBadge(score: broker.trustScore),
                  ],
                ),
                if (location != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '($location)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
                if (commodities.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in commodities.take(_maxChips)) CommodityChip(label: c),
                      if (extra > 0) CommodityChip(label: '+$extra'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 12),
            child: Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppColors.textMutedLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Green trust-score pill shared by the directory card and broker profile.
class TrustBadge extends StatelessWidget {
  final int score;

  const TrustBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.shieldCheck, size: 12, color: AppColors.success),
          const SizedBox(width: 4),
          Text(
            '$score Trust',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small outlined commodity tag.
class CommodityChip extends StatelessWidget {
  final String label;

  const CommodityChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
      ),
    );
  }
}
