import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';

/// Comprehensive Help & Support screen for the RMSeller Enterprise App.
/// Provides authoritative guidance on Command Center metrics, profile management,
/// broker-mediated workflows, and issue reporting without fabricating external contact details.
class SellerHelpSupportScreen extends StatefulWidget {
  const SellerHelpSupportScreen({super.key});

  @override
  State<SellerHelpSupportScreen> createState() =>
      _SellerHelpSupportScreenState();
}

class _SellerHelpSupportScreenState extends State<SellerHelpSupportScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          AppCard(
            backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.5),
            borderColor: AppColors.primary.withValues(alpha: 0.2),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.helpCircle,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RMSeller Knowledge & Support',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Operational guidance, mandi mediation rules, and desk assistance.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Help Section 1: Dashboard & Command Center
          _buildHelpSection(
            icon: LucideIcons.layoutDashboard,
            title: '1. Seller Command Center & KPIs',
            content:
                '• Active Lots: Reflects physical commodity lots currently listed on the exchange.\n'
                '• In Negotiation: Active quotation counter-offers currently handled by your broker desk.\n'
                '• Booked Deals: Legally confirmed contracts with agreed rate, quantity, and loading dates.\n'
                '• Ready to Load: Lots cleared for warehouse dispatch and vehicle loading.\n\n'
                'Use pull-to-refresh on the dashboard at any time to re-sync metrics from the authoritative database.',
          ),
          const SizedBox(height: 12),

          // Help Section 2: Profile & Account Management
          _buildHelpSection(
            icon: LucideIcons.userCheck,
            title: '2. Profile & Enterprise Account',
            content:
                '• View & Edit: Open My Profile from the dashboard overflow menu or bottom navigation bar.\n'
                '• Editable Fields: Contact person full name, company name, registered mobile number, primary mandi hub, and GSTIN.\n'
                '• Read-Only Safeguards: Account UUID, login email, role (SELLER), and verification status are strictly protected under platform security rules.\n'
                '• Updating Details: Tap "Edit Profile", update your values, and tap "Save Changes". Unsaved changes can be discarded anytime using "Cancel".',
          ),
          const SizedBox(height: 12),

          // Help Section 3: Broker-Mediated Trading & Counterparty Shield
          _buildHelpSection(
            icon: LucideIcons.shieldCheck,
            title: '3. Mandi Mediation & Counterparty Shield',
            content:
                '• Mandatory Broker Mediation: Under agricultural trade regulations, all commodity listings and negotiations are conducted exclusively through authorized regional brokers.\n'
                '• Counterparty Shield: Direct buyer contacts and private buyer directory searches are strictly blocked. Counterparty identities remain shielded throughout negotiation.\n'
                '• Confidential Reserve Price: When posting lots, your reserve price is strictly confidential and never exposed to prospective buyers.',
          ),
          const SizedBox(height: 12),

          // Help Section 4: Commodity Listing & Quality
          _buildHelpSection(
            icon: LucideIcons.packagePlus,
            title: '4. Commodity Lots & Quality Parameters',
            content:
                '• Posting Lots: Tap the "+" action on the Commodities tab to list a new lot.\n'
                '• Parameters: Specify commodity, variety grade, total quantity (MT/Quintals), moisture %, foreign matter %, and warehouse location.\n'
                '• Lab Reports: Attach existing NABL-accredited laboratory test certificates or quality reports if available.',
          ),
          const SizedBox(height: 12),

          // Help Section 5: Deals & Settlement
          _buildHelpSection(
            icon: LucideIcons.handshake,
            title: '5. Deals, Contracts & Dispatches',
            content:
                '• Deal Contracts: Review finalized transaction terms, delivery schedules, and payment terms.\n'
                '• Dispatches: Mark loading readiness and upload transport documents (Lorry Receipt / Bilty, Weighbridge slip).\n'
                '• Statements: Export sales history and transaction records from the Reports tab.',
          ),
          const SizedBox(height: 16),

          // Support Channel Honesty Notice Card
          AppCard(
            backgroundColor: AppColors.surfaceLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      LucideIcons.phoneCall,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Verified Support Channels',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dedicated telephone helpline and WhatsApp desk numbers are scheduled for release alongside regional mandi hub deployment.\n\n'
                  'For active trade disputes, commission clarification, or loading delays, please coordinate directly with your designated broker desk via the My Brokers screen.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'In-app support tickets are not available yet.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 10),
                AppButton(
                  key: const Key('help_contact_broker_button'),
                  label: 'Contact My Broker Desk',
                  icon: LucideIcons.users,
                  variant: ButtonVariant.primary,
                  onPressed: () => context.go('/brokers'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHelpSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: Icon(icon, color: AppColors.primary, size: 20),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 10),
                child: Text(
                  content,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
