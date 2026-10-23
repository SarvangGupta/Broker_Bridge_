import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/core/config/app_config.dart';
import 'package:rmbroker_mobile/features/authentication/domain/broker_user.dart';

/// Trading Desk introduction banner with broker identity, live operations access, and statutory fiduciary notice.
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
    final role = (broker?.role ?? 'Broker').toUpperCase();
    final greeting = _getTimeBasedGreeting();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Trading Desk Introduction Card — matching reference visual
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFE8F8F0), // Soft mint
                Color(0xFFF3FAF5), // Pale mint cream
                Color(0xFFFEFCE8), // Warm light tint
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD1FAE5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Column: Desk Title, Subtitle, Broker Identity
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Your Trading Desk',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A), // Deep navy
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCFBF1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F766E),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Deals · Requirements · Offers · Logistics',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '$greeting, ',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
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

              const SizedBox(width: 8),

              // Right side: chart graphic stacked above Live Operations button
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Rising green chart with upward arrow
                  const _TradingChartGraphic(),
                  const SizedBox(height: 6),
                  // Live Operations button
                  InkWell(
                    onTap: () => context.go('/deals?filter=active'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFA7F3D0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            LucideIcons.calendar,
                            size: 13,
                            color: Color(0xFF0F766E),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Live Ops',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 12,
                            color: Color(0xFF0F766E),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Statutory Fiduciary Notice (English)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFFDE68A),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(LucideIcons.shieldAlert, size: 14, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppConfig.fiduciaryNoticeEn,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
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
      width: 44,
      height: 32,
      child: CustomPaint(
        painter: _TradingChartPainter(),
      ),
    );
  }
}

class _TradingChartPainter extends CustomPainter {
  const _TradingChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 4 ascending green bars matching visual reference
    final barPaint = Paint()
      ..color = const Color(0xFF22C55E) // Green 500
      ..style = PaintingStyle.fill;

    const barWidth = 4.5;
    const barSpacing = 3.0;
    final heights = [8.0, 14.0, 20.0, 26.0];

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
      ..color = const Color(0xFF16A34A) // Green 600
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(1.0, size.height - 12);
    path.quadraticBezierTo(size.width * 0.45, size.height - 18, size.width - 6, 4);
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
