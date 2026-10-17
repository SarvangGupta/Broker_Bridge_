import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../utils/phone_utils.dart';

/// Ergonomic user-initiated action buttons for Phone Dialler and WhatsApp communication.
class ContactActionButtons extends StatelessWidget {
  final String? mobile;
  final String? contactName;
  final String? companyName;
  final bool isCompact;

  const ContactActionButtons({
    super.key,
    required this.mobile,
    this.contactName,
    this.companyName,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final validation = PhoneUtils.validateAndNormalize(mobile);
    final isValid = validation.isValid;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Device Phone Dialler Action
        _buildActionButton(
          context: context,
          icon: LucideIcons.phone,
          label: isCompact ? null : 'Call',
          color: const Color(0xFF0D9488), // Teal
          backgroundColor: const Color(0xFFF0FDFA),
          borderColor: const Color(0xFFCCFBF1),
          isEnabled: isValid,
          tooltip: isValid ? 'Call ${validation.formatted}' : 'Invalid contact number',
          onTap: () {
            PhoneUtils.launchDialler(context, mobile);
          },
        ),
        const SizedBox(width: 8),

        // 2. WhatsApp Direct Messaging Action
        _buildActionButton(
          context: context,
          icon: LucideIcons.messageSquare,
          label: isCompact ? null : 'WhatsApp',
          color: const Color(0xFF25D366), // Official WhatsApp Green
          backgroundColor: const Color(0xFFF0FDF4),
          borderColor: const Color(0xFFDCFCE7),
          isEnabled: isValid,
          tooltip: isValid ? 'Chat with ${contactName ?? "counterparty"} on WhatsApp' : 'Invalid contact number',
          onTap: () {
            final initialMsg = companyName != null
                ? 'Hello $contactName ($companyName), reaching out from RMBroker regarding commodity trade mandates.'
                : 'Hello, reaching out from RMBroker regarding commodity trade mandates.';
            PhoneUtils.launchWhatsApp(context, mobile, initialMessage: initialMsg);
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String? label,
    required Color color,
    required Color backgroundColor,
    required Color borderColor,
    required bool isEnabled,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final effectiveColor = isEnabled ? color : AppColors.textDisabled;
    final effectiveBg = isEnabled ? backgroundColor : Colors.grey.shade100;
    final effectiveBorder = isEnabled ? borderColor : Colors.grey.shade200;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 40,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: label != null ? 10 : 8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: effectiveBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: effectiveColor),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: effectiveColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
