import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../authentication/domain/broker_user.dart';
import '../../../deals/domain/deal_model.dart';
import '../../../deals/presentation/controllers/deals_controller.dart';
import '../../../profile/presentation/broker_profile_screen.dart';
import '../../../work/presentation/controllers/offers_controller.dart';
import '../../../work/presentation/controllers/requirements_controller.dart';
import '../../../work/presentation/widgets/create_requirement_sheet.dart';

/// Compact, two-column broker dashboard header:
/// - Left: Weather icon, time-based greeting, dynamic broker name with edit icon,
///         verified broker badge, and firm/business name.
/// - Right: Three live counters (Buyer Requirements, Seller Offers, Active Deals)
///          and a prominent "Post Requirement" button.
class BrokerWelcomeBanner extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Live Data Sources for Counters
    final reqState = ref.watch(requirementsProvider);
    final offerState = ref.watch(offersProvider);
    final dealsState = ref.watch(dealsProvider);

    final reqCount = reqState.totalCount > 0 ? reqState.totalCount : reqState.requirements.length;
    final offerCount = offerState.totalCount > 0 ? offerState.totalCount : offerState.offers.length;
    final dealCount = dealsState.deals.where((d) => d.status != DealStatus.cancelled && d.status != DealStatus.completed).length;

    // 2. Broker Profile Details — extract from AsyncValue using .when()
    final profileAsync = ref.watch(brokerProfileProvider);
    final profile = profileAsync.when(
      data: (p) => p,
      loading: () => null,
      error: (_, __) => null,
    );

    final String fullName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : (broker?.fullName.isNotEmpty == true ? broker!.fullName : 'Varun');

    // Display clean first name or full name if short
    final String displayName = fullName.trim();

    final bool isVerified = profile?.isVerified ?? (broker?.isBrokerOrAdmin ?? true);

    final String firmName = profile?.brokerageName.isNotEmpty == true
        ? profile!.brokerageName
        : 'RB Traders Pvt. Ltd.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('home_greeting_card'),
            onTap: () => context.push('/profile'),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFFAF3),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD1FAE5), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 360;

                  final leftSection = _buildLeftSection(
                    context: context,
                    greeting: _getTimeBasedGreeting(),
                    name: displayName,
                    isVerified: isVerified,
                    firmName: firmName,
                  );

                  final rightSection = _buildRightSection(
                    context: context,
                    reqCount: reqCount,
                    offerCount: offerCount,
                    dealCount: dealCount,
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        leftSection,
                        const SizedBox(height: 12),
                        rightSection,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: leftSection),
                      const SizedBox(width: 10),
                      Expanded(flex: 5, child: rightSection),
                    ],
                  );
                },
              ),
            ),
          ),
        ),

        // Contract Transparency Notice when endpoint is pending
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

  Widget _buildLeftSection({
    required BuildContext context,
    required String greeting,
    required String name,
    required bool isVerified,
    required String firmName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(LucideIcons.sun, size: 28, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$greeting,',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryNavy,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        key: const ValueKey('dashboard_edit_profile_button'),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        tooltip: 'Edit Broker Profile',
                        icon: const Icon(LucideIcons.pencil, size: 13, color: AppColors.primaryNavy),
                        onPressed: () => context.push('/profile'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVerified ? LucideIcons.check : LucideIcons.clock,
                    size: 11,
                    color: isVerified ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isVerified ? 'Verified Broker' : 'Pending Verification',
                    key: const ValueKey('dashboard_broker_verification_badge'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isVerified ? const Color(0xFF15803D) : const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 11, color: const Color(0xFFCBD5E1)),
            Text(
              firmName,
              key: const ValueKey('dashboard_broker_firm_name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightSection({
    required BuildContext context,
    required int reqCount,
    required int offerCount,
    required int dealCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 3 Compact Information Counters
        Row(
          children: [
            Expanded(
              child: _buildCounterItem(
                icon: LucideIcons.fileText,
                iconColor: const Color(0xFF7C3AED),
                count: reqCount,
                label: 'Buyer\nRequirements',
                keyName: 'counter_buyer_requirements',
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildCounterItem(
                icon: LucideIcons.tag,
                iconColor: const Color(0xFF059669),
                count: offerCount,
                label: 'Seller\nOffers',
                keyName: 'counter_seller_offers',
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildCounterItem(
                icon: Icons.handshake_outlined,
                iconColor: const Color(0xFFD97706),
                count: dealCount,
                label: 'Active\nDeals',
                keyName: 'counter_active_deals',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Prominent Post Requirement Button
        Material(
          color: const Color(0xFF0F766E),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: const ValueKey('home_post_requirement'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => CreateRequirementSheet.show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.20),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.plus,
                      size: 12,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Flexible(
                    child: Text(
                      'Post Requirement',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    LucideIcons.chevronDown,
                    size: 13,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCounterItem({
    required IconData icon,
    required Color iconColor,
    required int count,
    required String label,
    required String keyName,
  }) {
    return Column(
      key: ValueKey(keyName),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                '$count',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
