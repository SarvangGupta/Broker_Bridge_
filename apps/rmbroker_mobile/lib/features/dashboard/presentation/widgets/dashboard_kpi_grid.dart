import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/features/dashboard/domain/dashboard_models.dart';

/// Styling token bundle for pastel metric cards matching the visual reference.
class _KpiVisualTheme {
  final Color surfaceColor;
  final Color borderColor;
  final Color iconContainerColor;
  final Color iconColor;
  final Color badgeBgColor;
  final Color badgeTextColor;
  final Color chevronBgColor;
  final Color chevronIconColor;
  final Color watermarkColor;

  const _KpiVisualTheme({
    required this.surfaceColor,
    required this.borderColor,
    required this.iconContainerColor,
    required this.iconColor,
    required this.badgeBgColor,
    required this.badgeTextColor,
    required this.chevronBgColor,
    required this.chevronIconColor,
    required this.watermarkColor,
  });
}

_KpiVisualTheme _resolveCardTheme(String id) {
  switch (id) {
    case 'active_deals':
      return const _KpiVisualTheme(
        surfaceColor: Color(0xFFF0FDF4), // Soft Mint 50
        borderColor: Color(0xFF86EFAC), // Green 300
        iconContainerColor: Color(0xFF16A34A), // Rich Green 600
        iconColor: Colors.white,
        badgeBgColor: Color(0xFFDCFCE7),
        badgeTextColor: Color(0xFF166534),
        chevronBgColor: Color(0xFFDCFCE7),
        chevronIconColor: Color(0xFF16A34A),
        watermarkColor: Color(0xFF86EFAC),
      );
    case 'open_requirements':
      return const _KpiVisualTheme(
        surfaceColor: Color(0xFFEFF6FF), // Soft Blue 50
        borderColor: Color(0xFFBFDBFE), // Blue 200
        iconContainerColor: Color(0xFF2563EB), // Rich Blue 600
        iconColor: Colors.white,
        badgeBgColor: Color(0xFFDBEAFE),
        badgeTextColor: Color(0xFF1E40AF),
        chevronBgColor: Color(0xFFDBEAFE),
        chevronIconColor: Color(0xFF2563EB),
        watermarkColor: Color(0xFF93C5FD),
      );
    case 'partially_allocated':
      return const _KpiVisualTheme(
        surfaceColor: Color(0xFFFFFBEB), // Soft Amber 50
        borderColor: Color(0xFFFDE68A), // Amber 200
        iconContainerColor: Color(0xFFF59E0B), // Rich Amber 500
        iconColor: Colors.white,
        badgeBgColor: Color(0xFFFEF3C7),
        badgeTextColor: Color(0xFF92400E),
        chevronBgColor: Color(0xFFFEF3C7),
        chevronIconColor: Color(0xFFD97706),
        watermarkColor: Color(0xFFFCD34D),
      );
    case 'available_offers':
      return const _KpiVisualTheme(
        surfaceColor: Color(0xFFFAF5FF), // Soft Violet 50
        borderColor: Color(0xFFDDD6FE), // Violet 200
        iconContainerColor: Color(0xFF7C3AED), // Rich Violet 600
        iconColor: Colors.white,
        badgeBgColor: Color(0xFFEDE9FE),
        badgeTextColor: Color(0xFF6D28D9),
        chevronBgColor: Color(0xFFEDE9FE),
        chevronIconColor: Color(0xFF7C3AED),
        watermarkColor: Color(0xFFD8B4FE),
      );
    case 'awaiting_confirmation':
      return const _KpiVisualTheme(
        surfaceColor: Color(0xFFF0F9FF), // Soft Sky/Cyan 50
        borderColor: Color(0xFFBAE6FD), // Sky 200
        iconContainerColor: Color(0xFF0284C7), // Rich Sky 600
        iconColor: Colors.white,
        badgeBgColor: Color(0xFFFFE4E6), // Peach/Rose pill
        badgeTextColor: Color(0xFFE11D48),
        chevronBgColor: Color(0xFFE0F2FE),
        chevronIconColor: Color(0xFF0284C7),
        watermarkColor: Color(0xFF7DD3FC),
      );
    case 'dispatch_due':
      return const _KpiVisualTheme(
        surfaceColor: Color(0xFFFFF7ED), // Soft Orange 50
        borderColor: Color(0xFFFED7AA), // Orange 200
        iconContainerColor: Color(0xFFEA580C), // Rich Orange 600
        iconColor: Colors.white,
        badgeBgColor: Color(0xFFFFE4E6), // Peach/Rose pill
        badgeTextColor: Color(0xFFE11D48),
        chevronBgColor: Color(0xFFFFEDD5),
        chevronIconColor: Color(0xFFEA580C),
        watermarkColor: Color(0xFFFDBA74),
      );
    case 'commission_ledger':
      return const _KpiVisualTheme(
        surfaceColor: Color(0xFFF0FDF4), // Soft Emerald 50
        borderColor: Color(0xFFA7F3D0), // Emerald 200
        iconContainerColor: Color(0xFF10B981), // Rich Emerald 500
        iconColor: Colors.white,
        badgeBgColor: Color(0xFFD1FAE5),
        badgeTextColor: Color(0xFF059669),
        chevronBgColor: Color(0xFFD1FAE5),
        chevronIconColor: Color(0xFF059669),
        watermarkColor: Color(0xFF6EE7B7),
      );
    case 'open_disputes':
      return const _KpiVisualTheme(
        surfaceColor: Color(0xFFFEF2F2), // Soft Red 50
        borderColor: Color(0xFFFECACA), // Red 200
        iconContainerColor: Color(0xFFEF4444), // Rich Red 500
        iconColor: Colors.white,
        badgeBgColor: Color(0xFFFEE2E2),
        badgeTextColor: Color(0xFF991B1B),
        chevronBgColor: Color(0xFFFEE2E2),
        chevronIconColor: Color(0xFFDC2626),
        watermarkColor: Color(0xFFFCA5A5),
      );
    default:
      return const _KpiVisualTheme(
        surfaceColor: Color(0xFFF8FAFC),
        borderColor: Color(0xFFE2E8F0),
        iconContainerColor: Color(0xFF0F766E),
        iconColor: Colors.white,
        badgeBgColor: Color(0xFFF1F5F9),
        badgeTextColor: Color(0xFF64748B),
        chevronBgColor: Color(0xFFF1F5F9),
        chevronIconColor: Color(0xFF0F766E),
        watermarkColor: Color(0xFFCBD5E1),
      );
  }
}

/// Grid displaying 8 operational KPI summary cards for the broker desk.
class DashboardKpiGrid extends StatelessWidget {
  final List<BrokerKpiCard> cards;
  final VoidCallback? onRefresh;

  const DashboardKpiGrid({
    super.key,
    required this.cards,
    this.onRefresh,
  });

  void _onCardTap(BuildContext context, BrokerKpiCard card) {
    if (card.route != null && card.route!.isNotEmpty) {
      context.go(card.route!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${card.title}: Authoritative data source connected'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayFormatted = DateFormat('d MMM yyyy').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Desk Summary Metrics',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Today, $todayFormatted',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 1,
                  height: 12,
                  color: const Color(0xFFCBD5E1),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      LucideIcons.rotateCw,
                      size: 15,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
          ),
          itemBuilder: (context, index) {
            final card = cards[index];
            return _KpiCardItem(
              card: card,
              onTap: () => _onCardTap(context, card),
            );
          },
        ),
      ],
    );
  }
}

class _KpiCardItem extends StatelessWidget {
  final BrokerKpiCard card;
  final VoidCallback onTap;

  const _KpiCardItem({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = _resolveCardTheme(card.id);

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row: Solid colored icon container + Title
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.iconContainerColor,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Icon(
                          card.icon,
                          size: 16,
                          color: theme.iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        card.title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Middle: Prominent Value + Trend Badge + Chevron Action Circle
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          card.value,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    if (card.badge != null && card.isAvailable) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5.5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.badgeBgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          card.badge!,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: theme.badgeTextColor,
                          ),
                        ),
                      ),
                    ],
                    if (!card.isAvailable) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text(
                          'Pending API',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.chevronBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          LucideIcons.chevronRight,
                          size: 13,
                          color: theme.chevronIconColor,
                        ),
                      ),
                    ),
                  ],
                ),

                // Bottom row: Ascending mini-bar indicator + Subtitle
                Row(
                  children: [
                    _MiniBarWatermark(color: theme.watermarkColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        card.subtitle,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ascending mini bar chart graphic placed before the card subtitle.
class _MiniBarWatermark extends StatelessWidget {
  final Color color;

  const _MiniBarWatermark({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 3,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          width: 3,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          width: 3,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}
