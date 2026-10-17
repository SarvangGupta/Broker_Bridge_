import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/directory_contact.dart';
import 'contact_action_buttons.dart';

/// Counterparty card in the directory list.
class DirectoryContactCard extends StatelessWidget {
  final DirectoryContact contact;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const DirectoryContactCard({
    super.key,
    required this.contact,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isBuyer = contact.role == ContactRole.buyer;
    final roleColor = isBuyer ? const Color(0xFF1E3A8A) : const Color(0xFF0D9488);
    final roleBg = isBuyer ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDFA);
    final roleBorder = isBuyer ? const Color(0xFFDBEAFE) : const Color(0xFFCCFBF1);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: contact.status ? AppColors.borderLight : Colors.grey.shade300,
        ),
      ),
      color: contact.status ? Colors.white : Colors.grey.shade50,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Badges (Role, Status, Trust)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: roleBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: roleBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isBuyer ? LucideIcons.shoppingBag : LucideIcons.store,
                          size: 11,
                          color: roleColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          contact.role.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: roleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Verification Badge
                  if (contact.isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.shieldCheck, size: 11, color: Color(0xFF059669)),
                          SizedBox(width: 3),
                          Text(
                            'Verified',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  // Inactive / Archived indicator
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
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                  // Trust Score
                  if (contact.status && contact.trustScore > 0)
                    Text(
                      '${contact.trustScore}% Trust',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Company Name & Contact Name
              Text(
                contact.companyName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              Row(
                children: [
                  const Icon(LucideIcons.user, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Location (City, State)
              if (contact.city != null || contact.state != null)
                Row(
                  children: [
                    const Icon(LucideIcons.mapPin, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        contact.locationLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),

              const Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 10),

              // Bottom Row: Live Mandates Count + Action Buttons
              Row(
                children: [
                  // Mandates chips
                  _buildMandatesBadge(contact),

                  const Spacer(),

                  // Safe Call and WhatsApp Buttons
                  ContactActionButtons(
                    mobile: contact.mobile,
                    contactName: contact.name,
                    companyName: contact.companyName,
                    isCompact: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMandatesBadge(DirectoryContact contact) {
    if (contact.role == ContactRole.buyer) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.package, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              '${contact.openRequirementsCount} Reqs',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.store, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              '${contact.availableOffersCount} Lots',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }
  }
}
