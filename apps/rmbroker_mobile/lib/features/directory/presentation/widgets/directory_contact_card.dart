import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/directory_contact.dart';
import 'contact_action_buttons.dart';

/// Compact counterparty row in the directory list. Tapping the row opens the
/// details; the call and WhatsApp buttons handle their own taps.
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

  static const _buyerColor = Color(0xFF1D4ED8);
  static const _buyerBg = Color(0xFFEFF6FF);
  static const _sellerColor = Color(0xFFC2410C);
  static const _sellerBg = Color(0xFFFFF7ED);
  static const _verifiedColor = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    final isBuyer = contact.role == ContactRole.buyer;
    final roleColor = isBuyer ? _buyerColor : _sellerColor;
    final roleBg = isBuyer ? _buyerBg : _sellerBg;
    final initialSource = contact.companyName.trim().isNotEmpty ? contact.companyName : contact.name;
    final initial = initialSource.trim().isEmpty ? '?' : initialSource.trim()[0].toUpperCase();
    final muted = contact.status ? AppColors.textSecondary : AppColors.textDisabled;

    return Material(
      color: contact.status ? Colors.white : Colors.grey.shade50,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: roleBg,
                child: Text(
                  initial,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: roleColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    _iconLine(LucideIcons.user, contact.name, muted),
                    if (contact.hasLocation) ...[
                      const SizedBox(height: 2),
                      _iconLine(LucideIcons.mapPin, contact.locationLabel, muted),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: roleBg, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            contact.role.label,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: roleColor),
                          ),
                        ),
                        if (contact.isVerified)
                          const Row(
                            key: Key('contact_verified_badge'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.badgeCheck, size: 14, color: _verifiedColor),
                              SizedBox(width: 3),
                              Text(
                                'Verified',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _verifiedColor),
                              ),
                            ],
                          ),
                        if (contact.isBrokerVerified)
                          Container(
                            key: const Key('contact_broker_verified_badge'),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.fileCheck2, size: 12, color: Color(0xFF15803D)),
                                SizedBox(width: 3),
                                Text(
                                  'Certificate Reviewed',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ),
                        if (contact.isGstPending)
                          Container(
                            key: const Key('contact_gst_pending_badge'),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.clock, size: 12, color: Color(0xFFB45309)),
                                SizedBox(width: 3),
                                Text(
                                  'GST Pending',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                        if (!contact.status)
                          const Text(
                            'ARCHIVED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ContactActionButtons(
                      mobile: contact.mobile,
                      contactName: contact.name,
                      companyName: contact.companyName,
                      isCompact: true,
                    ),
                    const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconLine(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: color),
          ),
        ),
      ],
    );
  }
}
