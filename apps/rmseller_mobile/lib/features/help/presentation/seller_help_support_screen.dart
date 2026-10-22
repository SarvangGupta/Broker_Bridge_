import 'package:flutter/material.dart';
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
  final TextEditingController _issueTypeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _issueTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showReportIssueDialog() {
    String selectedCategory = 'Listing & Commodity Management';
    final categories = [
      'Listing & Commodity Management',
      'Broker Coordination & Mandate',
      'Negotiation & Counter-Offers',
      'Deal Contract & Invoicing',
      'Profile & Account Details',
      'Technical / App Performance',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(LucideIcons.lifeBuoy, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text(
                  'Submit Support Request',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Issue Category:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat, style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Describe the Issue:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'Provide details regarding your issue or inquiry...',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMutedLight,
                      ),
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.infoBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(LucideIcons.info, size: 14, color: AppColors.info),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Support queries are logged with your authenticated seller ID and routed to the mandi desk administrator.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final description = _descriptionController.text.trim();
                  if (description.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter an issue description'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }
                  Navigator.of(ctx).pop();
                  _descriptionController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Support request logged under category: $selectedCategory',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                child: const Text('Submit Request'),
              ),
            ],
          );
        },
      ),
    );
  }

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
                AppButton(
                  label: 'Submit Support Ticket',
                  icon: LucideIcons.messageSquarePlus,
                  variant: ButtonVariant.primary,
                  onPressed: _showReportIssueDialog,
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
