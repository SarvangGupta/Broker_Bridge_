import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/requirement_model.dart';
import '../controllers/requirements_controller.dart';

enum RequirementDetailAction {
  negotiate,
  findMatches,
}

class RequirementDetailSheet extends ConsumerWidget {
  final RequirementItem requirement;
  final VoidCallback? onFindMatches;

  const RequirementDetailSheet({
    super.key,
    required this.requirement,
    this.onFindMatches,
  });

  static Future<RequirementDetailAction?> show({
    required BuildContext context,
    required RequirementItem requirement,
    VoidCallback? onFindMatches,
  }) {
    return showModalBottomSheet<RequirementDetailAction>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RequirementDetailSheet(
        requirement: requirement,
        onFindMatches: onFindMatches,
      ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          title: const Text('Cancel Requirement Mandate', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to cancel ${requirement.ref}? Please provide an audit reason.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Cancellation Reason *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext),
              child: const Text('Keep Active'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.length < 3) return;
                Navigator.pop(dlgContext);
                final success = await ref
                    .read(requirementsProvider.notifier)
                    .cancelRequirement(requirement.id, reason);
                if (context.mounted && success) {
                  Navigator.pop(context); // Close sheet
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Requirement cancelled successfully')),
                  );
                }
              },
              child: const Text('Confirm Cancel', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuantityRow(String label, double qty, String unit, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$qty $unit',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Row(
              children: [
                Text(
                  requirement.ref,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    requirement.status.displayLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Commodity & Buyer
            Text(
              requirement.commodityName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Grade: ${requirement.gradeName}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.building, size: 14, color: AppColors.textSecondaryLight),
                const SizedBox(width: 5),
                Text(
                  requirement.buyerCompanyName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (requirement.isBuyerVerified)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.verified, size: 14, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // All 7 Quantities Breakdown (Prompt Section 3 Requirement)
            const Text(
              'Quantity Lifecycle Breakdown',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _buildQuantityRow(
                    '1. Requested Volume',
                    requirement.requestedQuantity,
                    requirement.unitSymbol,
                    AppColors.textPrimaryLight,
                  ),
                  const Divider(height: 10),
                  _buildQuantityRow(
                    '2. Allocated Volume',
                    requirement.allocatedQuantity,
                    requirement.unitSymbol,
                    AppColors.primary,
                  ),
                  _buildQuantityRow(
                    '3. Contracted Volume',
                    requirement.contractedQuantity,
                    requirement.unitSymbol,
                    const Color(0xFF0D9488),
                  ),
                  _buildQuantityRow(
                    '4. Delivered Volume',
                    requirement.deliveredQuantity,
                    requirement.unitSymbol,
                    AppColors.success,
                  ),
                  _buildQuantityRow(
                    '5. Accepted Volume',
                    requirement.acceptedQuantity,
                    requirement.unitSymbol,
                    AppColors.success,
                  ),
                  _buildQuantityRow(
                    '6. Disputed / Rejected',
                    requirement.disputedQuantity,
                    requirement.unitSymbol,
                    AppColors.error,
                  ),
                  const Divider(height: 10),
                  _buildQuantityRow(
                    '7. Remaining Unallocated',
                    requirement.remainingQuantity,
                    requirement.unitSymbol,
                    const Color(0xFFD97706),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Price & Delivery Specs
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Target Price', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                      const SizedBox(height: 2),
                      Text(
                        '₹${requirement.targetPrice.toInt()} / ${requirement.unitSymbol}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Target Delivery Date', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                      const SizedBox(height: 2),
                      Text(
                        requirement.targetDateFormatted,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Delivery Terms: ${requirement.deliveryTerms}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimaryLight),
            ),
            if (requirement.notes != null) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${requirement.notes}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              ),
            ],
            const SizedBox(height: 20),

            // Action Buttons
            if (requirement.status != RequirementStatus.cancelled && requirement.status != RequirementStatus.fulfilled) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(LucideIcons.scale, size: 18),
                  label: Text(
                    requirement.isProposed
                        ? 'View / Amend Commercial Proposal'
                        : 'Initiate Negotiation & Submit Proposal',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(RequirementDetailAction.negotiate);
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                if (requirement.status != RequirementStatus.cancelled) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    icon: const Icon(LucideIcons.ban, size: 16),
                    label: const Text('Cancel Mandate'),
                    onPressed: () => _showCancelDialog(context, ref),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: requirement.status != RequirementStatus.cancelled && requirement.status != RequirementStatus.fulfilled
                          ? AppColors.surfaceLight
                          : AppColors.primary,
                      foregroundColor: requirement.status != RequirementStatus.cancelled && requirement.status != RequirementStatus.fulfilled
                          ? AppColors.primary
                          : Colors.white,
                      side: requirement.status != RequirementStatus.cancelled && requirement.status != RequirementStatus.fulfilled
                          ? const BorderSide(color: AppColors.primary)
                          : BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text('Find Matching Offers', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () {
                      Navigator.of(context).pop(RequirementDetailAction.findMatches);
                      onFindMatches?.call();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
