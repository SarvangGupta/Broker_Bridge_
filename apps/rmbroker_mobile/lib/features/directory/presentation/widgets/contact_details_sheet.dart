import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/directory_contact.dart';
import '../../domain/directory_state.dart';
import '../controllers/contact_details_controller.dart';
import 'contact_action_buttons.dart';
import 'contact_form_modal.dart';

/// 360-degree bottom sheet view showing contact details, linked business mandates, and archival actions.
class ContactDetailsSheet extends ConsumerWidget {
  final DirectoryContact initialContact;

  const ContactDetailsSheet({
    super.key,
    required this.initialContact,
  });

  static void show(BuildContext context, DirectoryContact contact) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ContactDetailsSheet(initialContact: contact),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsState = ref.watch(contactDetailsControllerProvider(initialContact.id));
    final controller = ref.read(contactDetailsControllerProvider(initialContact.id).notifier);

    final contact = detailsState.payload?.contact ?? initialContact;
    final isBuyer = contact.role == ContactRole.buyer;
    final roleColor = isBuyer ? const Color(0xFF1E3A8A) : const Color(0xFF0D9488);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              contact.role.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: roleColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (contact.isVerified)
                            const Icon(LucideIcons.shieldCheck, size: 16, color: Color(0xFF059669)),
                          const Spacer(),
                          if (!contact.status)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ARCHIVED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        contact.companyName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Quick Action Bar: Call, WhatsApp, Edit, Soft Archive
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.backgroundLight,
            child: Row(
              children: [
                ContactActionButtons(
                  mobile: contact.mobile,
                  contactName: contact.name,
                  companyName: contact.companyName,
                  isCompact: false,
                ),
                const Spacer(),
                // Edit Button
                IconButton(
                  tooltip: 'Edit Counterparty',
                  icon: const Icon(LucideIcons.edit2, size: 18, color: AppColors.primaryNavy),
                  onPressed: () {
                    Navigator.of(context).pop();
                    ContactFormModal.show(
                      context,
                      isEditing: true,
                      existingContact: contact,
                      defaultRole: contact.role,
                    );
                  },
                ),
                // Soft Archive Toggle
                IconButton(
                  tooltip: contact.status ? 'Archive Counterparty' : 'Reactivate Counterparty',
                  icon: Icon(
                    contact.status ? LucideIcons.archive : LucideIcons.archiveRestore,
                    size: 18,
                    color: contact.status ? Colors.amber.shade800 : Colors.teal.shade800,
                  ),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(contact.status ? 'Archive Contact?' : 'Reactivate Contact?'),
                        content: Text(
                          contact.status
                              ? 'This will mark ${contact.name} (${contact.companyName}) as archived. No transaction or mandate records will be deleted.'
                              : 'Reactivate this contact and restore them to active directory listings?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: contact.status ? Colors.amber.shade800 : AppColors.primaryNavy,
                            ),
                            child: Text(contact.status ? 'Archive' : 'Reactivate'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await controller.toggleStatus();
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Scrollable Body: Profile Details & Linked Business Records
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact Metadata Card
                  _buildSectionHeader('Contact Information', LucideIcons.idCard),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Mobile Phone', contact.formattedMobile, LucideIcons.phone),
                        if (contact.email != null && contact.email!.isNotEmpty) ...[
                          const Divider(height: 16, color: AppColors.borderLight),
                          _buildInfoRow('Email Address', contact.email!, LucideIcons.mail),
                        ],
                        const Divider(height: 16, color: AppColors.borderLight),
                        _buildInfoRow('Mandi Location', contact.locationLabel, LucideIcons.mapPin),
                        const Divider(height: 16, color: AppColors.borderLight),
                        _buildInfoRow(
                          'Trust & Integrity',
                          '${contact.trustScore}% Score (${contact.isVerified ? "Platform Verified" : "Self-Reported"})',
                          LucideIcons.shieldCheck,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Linked Business Records (360-Degree Aggregation)
                  _buildSectionHeader(
                    isBuyer ? 'Linked Trade Requirements' : 'Linked Seller Offers',
                    isBuyer ? LucideIcons.package : LucideIcons.store,
                  ),
                  const SizedBox(height: 10),

                  if (detailsState.status == ContactDetailsStatus.loading) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ] else if (isBuyer) ...[
                    _buildRequirementsList(detailsState.payload?.associatedRequirements ?? []),
                  ] else ...[
                    _buildOffersList(detailsState.payload?.associatedOffers ?? []),
                  ],

                  const SizedBox(height: 20),

                  // Recent CRM Activity & Notes
                  _buildSectionHeader('Broker Interaction History', LucideIcons.clock),
                  const SizedBox(height: 10),
                  _buildActivitiesList(detailsState.payload?.activities ?? []),

                  const SizedBox(height: 24),

                  // Statutory Fiduciary Notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.info, size: 14, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Broker Mediation Firewall: All trade negotiations, quantity allocations, and contract confirmations remain strictly mediated by the broker. Direct buyer-seller trade communication is not permitted.',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryNavy),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementsList(List<LinkedRequirement> reqs) {
    if (reqs.isEmpty) {
      return _buildEmptyLinkedRecords('No active trade requirements on file for this buyer.');
    }

    return Column(
      children: reqs.map((r) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.commodityName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target: ${r.quantity.toInt()} MT @ ₹${r.targetPrice.toInt()}/Qtl',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.status,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOffersList(List<LinkedOffer> offers) {
    if (offers.isEmpty) {
      return _buildEmptyLinkedRecords('No active commodity lots available from this seller.');
    }

    return Column(
      children: offers.map((o) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.commodityName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Available: ${o.quantity.toInt()} MT • Asking: ${o.price}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCCFBF1)),
                ),
                child: Text(
                  o.status,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D9488),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivitiesList(List<ContactActivity> activities) {
    if (activities.isEmpty) {
      return _buildEmptyLinkedRecords('No CRM notes logged yet.');
    }

    return Column(
      children: activities.map((a) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(LucideIcons.fileText, size: 12, color: AppColors.primaryNavy),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.notes,
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                    if (a.createdAt.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        a.createdAt.substring(0, 10),
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyLinkedRecords(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
