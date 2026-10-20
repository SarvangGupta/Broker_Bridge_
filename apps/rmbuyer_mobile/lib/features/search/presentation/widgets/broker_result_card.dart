import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/contact_launcher_service.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/broker_model.dart';

/// Premium card displaying authorized broker information and contact actions.
/// Strictly enforces Counterparty Shield: seller identities and contact details
/// are never rendered.
class BrokerResultCard extends StatelessWidget {
  final BrokerModel broker;
  final ContactLauncherService? contactLauncher;
  final VoidCallback? onTap;

  const BrokerResultCard({
    super.key,
    required this.broker,
    this.contactLauncher,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final launcher = contactLauncher ?? ContactLauncherService();

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap ?? () => context.push('/brokers/${broker.id}', extra: broker),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Desk & Trust Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.briefcase,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      broker.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      broker.companyName ?? 'Licensed Mandi Desk',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 12,
                          color: AppColors.textMutedLight,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            broker.location ?? 'Mandi Floor',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMutedLight,
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
              // Trust Score & Verified Badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.successBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.shieldCheck,
                          size: 12,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${broker.trustScore} Trust',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (broker.isVerified) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'GST VERIFIED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Commodities Handled Chips
          if (broker.commoditiesHandled.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: broker.commoditiesHandled.take(4).map((c) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    c,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Action Buttons: Call & WhatsApp
          Row(
            children: [
              // Call Action
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: broker.hasPhone
                      ? () => launcher.launchCall(broker.mobile!)
                      : null,
                  icon: const Icon(LucideIcons.phone, size: 15),
                  label: const Text('Call Desk', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // WhatsApp Action
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: broker.hasWhatsApp
                      ? () => launcher.launchWhatsApp(
                            broker.mobile!,
                            prefilledMessage:
                                'Hello ${broker.name}, I am contacting you via RMBuyer regarding commodity procurement.',
                          )
                      : null,
                  icon: const Icon(LucideIcons.messageCircle, size: 15),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
