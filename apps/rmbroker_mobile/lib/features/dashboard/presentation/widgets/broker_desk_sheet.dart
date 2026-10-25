import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../directory/utils/phone_utils.dart';
import '../../../search/presentation/widgets/quick_communication_sheet.dart';

/// Broker Desk: compact two-column grid of communication shortcuts.
class BrokerDeskSheet extends StatelessWidget {
  /// Mandi Support WhatsApp number; empty when not configured.
  final String supportWhatsApp;

  const BrokerDeskSheet({super.key, this.supportWhatsApp = AppConfig.supportWhatsApp});

  static Future<void> show(BuildContext context, {String supportWhatsApp = AppConfig.supportWhatsApp}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppColors.surfaceLight,
      showDragHandle: true,
      builder: (_) => BrokerDeskSheet(supportWhatsApp: supportWhatsApp),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Actions run on the screen behind the sheet once the sheet has closed.
    final host = Navigator.of(context).context;
    void closeThen(void Function() action) {
      Navigator.pop(context);
      action();
    }

    final actions = <_DeskAction>[
      _DeskAction('Call', LucideIcons.phone, const Color(0xFF16A34A),
          () => closeThen(() => QuickCommunicationSheet.show(host))),
      _DeskAction('WhatsApp', LucideIcons.messageCircle, const Color(0xFF16A34A),
          () => closeThen(() => QuickCommunicationSheet.show(host))),
      _DeskAction('Directory', LucideIcons.users, const Color(0xFF2563EB),
          () => closeThen(() => host.go('/directory'))),
      _DeskAction('Mandi Support', LucideIcons.headset, const Color(0xFFEA580C), () {
        closeThen(() {
          if (supportWhatsApp.trim().isEmpty) {
            _snack(host, 'Mandi Support WhatsApp is not configured yet.');
          } else {
            PhoneUtils.launchWhatsApp(host, supportWhatsApp);
          }
        });
      }),
      _DeskAction('Chat', LucideIcons.messageSquare, const Color(0xFF7C3AED),
          () => closeThen(() => _snack(host, 'In-app chat is not available yet. Use Call or WhatsApp.'))),
      _DeskAction('Info', LucideIcons.info, const Color(0xFF1E3A5F), () => closeThen(() => _showInfo(host))),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Broker Desk',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
                  ),
                ),
                IconButton(
                  key: const ValueKey('broker_desk_close'),
                  tooltip: 'Close',
                  icon: const Icon(LucideIcons.x, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var row = 0; row < actions.length; row += 2) ...[
              Row(
                children: [
                  Expanded(child: _DeskCard(action: actions[row])),
                  const SizedBox(width: 10),
                  Expanded(child: _DeskCard(action: actions[row + 1])),
                ],
              ),
              if (row + 2 < actions.length) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  static void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dlg) => AlertDialog(
        title: const Text('Broker Desk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: const Text(
          'Call / WhatsApp: reach your authorized buyers and sellers.\n'
          'Directory: open your counterparty directory.\n'
          'Mandi Support: message the administrator support line.\n'
          'Chat: not available yet.',
          style: TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dlg), child: const Text('OK'))],
      ),
    );
  }
}

class _DeskAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _DeskAction(this.label, this.icon, this.color, this.onTap);
}

class _DeskCard extends StatelessWidget {
  final _DeskAction action;
  const _DeskCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('broker_desk_${action.label.toLowerCase().replaceAll(' ', '_')}'),
          onTap: action.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(color: action.color.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(action.icon, size: 22, color: action.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      action.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondaryLight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
