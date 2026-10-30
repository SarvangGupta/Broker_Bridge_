import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';
import 'package:rmbroker_mobile/features/work/presentation/widgets/create_requirement_sheet.dart';

/// Home greeting card: time-based greeting, broker name, tagline and the
/// Post Requirement shortcut (opens the existing requirement form).
class BrokerWelcomeBanner extends StatelessWidget {
  final BrokerUser? broker;
  final String? contractNotice;
  final bool isAuthoritative;
  final DateTime? lastRefreshed;

  const BrokerWelcomeBanner({
    super.key,
    this.broker,
    this.contractNotice,
    this.isAuthoritative = false,
    this.lastRefreshed,
  });

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = broker?.fullName.isNotEmpty == true
        ? broker!.fullName
        : 'Broker Desk';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('home_greeting_card'),
            onTap: () => context.push('/profile'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFFAF3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD1FAE5)),
              ),
              // One compact row: sun · greeting/name · (chart when wide) · Post Requirement.
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    const Icon(LucideIcons.sun, size: 30, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_getTimeBasedGreeting()},',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                key: const ValueKey('dashboard_edit_profile_button'),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Edit Broker Profile',
                                icon: const Icon(LucideIcons.pencil, size: 13, color: AppColors.primary),
                                onPressed: () => context.push('/profile'),
                              ),
                            ],
                          ),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryNavy,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (constraints.maxWidth >= 380) ...[
                      const SizedBox(width: 8),
                      const _TradingChartGraphic(),
                    ],
                    const SizedBox(width: 8),
                    Flexible(
                      child: OutlinedButton.icon(
                        key: const ValueKey('home_post_requirement'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryNavy,
                          side: const BorderSide(color: Color(0xFFD1FAE5)),
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Icon(
                            LucideIcons.plus,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        label: const Text(
                          'Post Requirement',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => CreateRequirementSheet.show(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Contract Transparency Notice when endpoint is not yet mounted
        if (contractNotice != null && !isAuthoritative) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.info,
                  size: 14,
                  color: Color(0xFF475569),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    contractNotice!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TradingChartGraphic extends StatelessWidget {
  const _TradingChartGraphic();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 56,
      height: 40,
      child: CustomPaint(painter: _TradingChartPainter()),
    );
  }
}

class _TradingChartPainter extends CustomPainter {
  const _TradingChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 4 ascending green bars matching visual reference
    final barPaint = Paint()
      ..color =
          const Color(0xFF22C55E) // Green 500
      ..style = PaintingStyle.fill;

    const barWidth = 6.0;
    const barSpacing = 4.0;
    final heights = [10.0, 17.0, 25.0, 33.0];

    for (int i = 0; i < heights.length; i++) {
      final x = i * (barWidth + barSpacing) + 2.0;
      final y = size.height - heights[i];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, heights[i]),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, barPaint);
    }

    // Upward curving arrow
    final arrowPaint = Paint()
      ..color =
          const Color(0xFF16A34A) // Green 600
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(1.0, size.height - 14);
    path.quadraticBezierTo(
      size.width * 0.45,
      size.height - 22,
      size.width - 6,
      4,
    );
    canvas.drawPath(path, arrowPaint);

    // Arrowhead
    final headPaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.fill;

    final headPath = Path();
    headPath.moveTo(size.width - 2, 2);
    headPath.lineTo(size.width - 8, 3);
    headPath.lineTo(size.width - 4, 8);
    headPath.close();
    canvas.drawPath(headPath, headPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
