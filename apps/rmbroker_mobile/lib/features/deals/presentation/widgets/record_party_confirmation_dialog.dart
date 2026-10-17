import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/deal_model.dart';
import '../controllers/deal_detail_controller.dart';
import '../controllers/deals_controller.dart';

/// Modal dialog allowing the authorized broker to record formal confirmation received
/// from the Buyer or Seller against the exact active version terms.
class RecordPartyConfirmationDialog extends ConsumerStatefulWidget {
  final String dealId;
  final DealDetailItem detail;

  const RecordPartyConfirmationDialog({
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
      builder: (context) => RecordPartyConfirmationDialog(
        dealId: dealId,
        detail: detail,
      ),
    );
  }

  @override
  ConsumerState<RecordPartyConfirmationDialog> createState() =>
      _RecordPartyConfirmationDialogState();
}

class _RecordPartyConfirmationDialogState
    extends ConsumerState<RecordPartyConfirmationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  String _selectedParty = 'BUYER';

  @override
  void initState() {
    super.initState();
    final conf = widget.detail.confirmations;
    // Default to the party that hasn't confirmed yet
    if (conf.buyerConfirmed && !conf.sellerConfirmed) {
      _selectedParty = 'SELLER';
    } else {
      _selectedParty = 'BUYER';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitConfirmation() async {
    if (!_formKey.currentState!.validate()) return;

    final notes = _notesController.text.trim();
    final party = _selectedParty;
    final dealNotifier = ref.read(dealDetailProvider(widget.dealId).notifier);

    final success = await dealNotifier.recordPartyConfirmation(party, notes: notes);

    if (mounted) {
      if (success) {
        ref.read(dealsProvider.notifier).loadDeals();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Formal $party confirmation recorded against active terms.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        final err = ref.read(dealDetailProvider(widget.dealId)).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Failed to record confirmation.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.detail.deal;
    final conf = widget.detail.confirmations;
    final currentVer = conf.latestVersionNumber;
    final state = ref.watch(dealDetailProvider(widget.dealId));

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
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.checkSquare, size: 20, color: AppColors.success),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record Confirmation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Targeting Version $currentVer Terms',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.shieldAlert, size: 14, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Broker Audit Rule: The broker coordinates deal terms but must only record genuine, verified confirmations received from counterparties.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Party Selector
              const Text(
                'Select Confirming Party *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedParty = 'BUYER'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedParty == 'BUYER'
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedParty == 'BUYER' ? AppColors.primary : AppColors.borderLight,
                            width: _selectedParty == 'BUYER' ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              LucideIcons.building2,
                              size: 18,
                              color: _selectedParty == 'BUYER' ? AppColors.primary : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Buyer',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _selectedParty == 'BUYER' ? AppColors.primary : AppColors.textPrimaryLight,
                              ),
                            ),
                            Text(
                              conf.buyerConfirmed ? '(Confirmed)' : '(Pending)',
                              style: TextStyle(
                                fontSize: 10,
                                color: conf.buyerConfirmed ? AppColors.success : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedParty = 'SELLER'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedParty == 'SELLER'
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedParty == 'SELLER' ? AppColors.primary : AppColors.borderLight,
                            width: _selectedParty == 'SELLER' ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              LucideIcons.store,
                              size: 18,
                              color: _selectedParty == 'SELLER' ? AppColors.primary : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Seller',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _selectedParty == 'SELLER' ? AppColors.primary : AppColors.textPrimaryLight,
                              ),
                            ),
                            Text(
                              conf.sellerConfirmed ? '(Confirmed)' : '(Pending)',
                              style: TextStyle(
                                fontSize: 10,
                                color: conf.sellerConfirmed ? AppColors.success : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Enterprise names reminder
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedParty == 'BUYER'
                      ? 'Buyer: ${deal.buyerCompanyName}'
                      : 'Seller: ${deal.sellerCompanyName}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),

              // Verification Notes (Mandatory for audit trail)
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Verification Notes *',
                  hintText: 'e.g. Confirmed via phone mandate and signed acceptance on 17-Oct',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Verification notes are required for audit trail';
                  }
                  if (v.trim().length < 3) return 'Notes must be at least 3 characters';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: state.isSubmitting ? null : _submitConfirmation,
          child: state.isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'Record $_selectedParty Acceptance',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}
