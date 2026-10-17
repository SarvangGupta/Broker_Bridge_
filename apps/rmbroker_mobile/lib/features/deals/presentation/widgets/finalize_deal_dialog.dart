import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/deal_model.dart';
import '../controllers/deal_detail_controller.dart';
import '../controllers/deals_controller.dart';

/// Pre-flight gate modal dialog for authoritative deal finalization.
/// Strictly enforces that BOTH Buyer and Seller have formally confirmed the current version
/// before allowing generation of the enterprise booking reference (BKG-YYYY-XXXX).
class FinalizeDealDialog extends ConsumerStatefulWidget {
  final String dealId;
  final DealDetailItem detail;

  const FinalizeDealDialog({
    super.key,
    required this.dealId,
    required this.detail,
  });

  static Future<void> show(
    BuildContext context, {
    required String dealId,
    required DealDetailItem detail,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => FinalizeDealDialog(
        dealId: dealId,
        detail: detail,
      ),
    );
  }

  @override
  ConsumerState<FinalizeDealDialog> createState() => _FinalizeDealDialogState();
}

class _FinalizeDealDialogState extends ConsumerState<FinalizeDealDialog> {
  bool _confirmedUnderstanding = false;

  Future<void> _executeFinalization() async {
    final conf = widget.detail.confirmations;
    if (!conf.canFinalize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot finalize: Both Buyer and Seller must confirm latest version.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final notifier = ref.read(dealDetailProvider(widget.dealId).notifier);
    final bookingRef = await notifier.finalizeDeal(conf.latestVersionNumber);

    if (mounted) {
      if (bookingRef != null) {
        ref.read(dealsProvider.notifier).loadDeals();
        Navigator.pop(context);
        _showSuccessDialog(context, bookingRef);
      } else {
        final err = ref.read(dealDetailProvider(widget.dealId)).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Pre-flight finalization gate rejected.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(BuildContext context, String bookingRef) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.checkCircle2, color: AppColors.success, size: 24),
            SizedBox(width: 10),
            Text('Deal Finalized', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The transaction contract has been authoritatively locked and registered with the exchange.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('OFFICIAL BOOKING REFERENCE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  const SizedBox(height: 4),
                  Text(
                    bookingRef,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Acknowledge & Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.detail.deal;
    final conf = widget.detail.confirmations;
    final state = ref.watch(dealDetailProvider(widget.dealId));
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final canProceed = conf.canFinalize && _confirmedUnderstanding;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.lock, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Finalize Contract Gate',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Contract Locking for ${deal.ref}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pre-flight Verification Checklist
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PRE-FLIGHT GATE VERIFICATION',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondaryLight,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 1. Version Check
                  _buildCheckItem(
                    'Active Terms Version: v${conf.latestVersionNumber}',
                    true,
                    'Both parties must confirm exact same version',
                  ),
                  const SizedBox(height: 6),

                  // 2. Buyer Confirmation Check
                  _buildCheckItem(
                    'Buyer Acceptance (${deal.buyerCompanyName})',
                    conf.buyerConfirmed,
                    conf.buyerConfirmed ? 'Verified & recorded' : 'Pending buyer formal acceptance',
                  ),
                  const SizedBox(height: 6),

                  // 3. Seller Confirmation Check
                  _buildCheckItem(
                    'Seller Acceptance (${deal.sellerCompanyName})',
                    conf.sellerConfirmed,
                    conf.sellerConfirmed ? 'Verified & recorded' : 'Pending seller formal acceptance',
                  ),
                  const SizedBox(height: 6),

                  // 4. Commercial Lock
                  _buildCheckItem(
                    'Valuation: ${currencyFormat.format(deal.totalValuation)} (${deal.formattedQuantity})',
                    true,
                    'Rate: ${currencyFormat.format(deal.agreedPrice)} / ${deal.unitSymbol}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Warning Banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.alertTriangle, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Finalizing this deal locks the transaction and generates an authoritative booking reference. Terms can no longer be modified or cancelled.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Confirmation checkbox
            if (conf.canFinalize)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _confirmedUnderstanding,
                onChanged: (val) => setState(() => _confirmedUnderstanding = val ?? false),
                title: Text(
                  'I confirm both counterparties have verified and approved all commercial terms in Version ${conf.latestVersionNumber}.',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'GATE BLOCKED: Both Buyer and Seller must confirm terms before finalization can proceed.',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Dismiss'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: canProceed ? AppColors.primary : AppColors.textSecondaryLight,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: canProceed && !state.isSubmitting ? _executeFinalization : null,
          child: state.isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Lock & Finalize Contract',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }

  Widget _buildCheckItem(String title, bool isSatisfied, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isSatisfied ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
          size: 15,
          color: isSatisfied ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isSatisfied ? AppColors.textPrimaryLight : AppColors.error,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
