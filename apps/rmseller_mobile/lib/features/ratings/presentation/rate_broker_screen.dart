import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../data/seller_ratings_repository.dart';
import '../domain/broker_rating_model.dart';

/// Screen allowing an authenticated Seller to rate an eligible Mandi Broker Desk.
/// Enforces rating eligibility, character validation, confirmation dialog,
/// in-flight double submission prevention, and Counterparty Shield privacy.
class RateBrokerScreen extends StatefulWidget {
  final String brokerId;
  final String brokerName;
  final String? dealId;
  final String? dealReference;
  final SellerRatingsRepository? repository;

  const RateBrokerScreen({
    super.key,
    required this.brokerId,
    required this.brokerName,
    this.dealId,
    this.dealReference,
    this.repository,
  });

  @override
  State<RateBrokerScreen> createState() => _RateBrokerScreenState();
}

class _RateBrokerScreenState extends State<RateBrokerScreen> {
  late final SellerRatingsRepository _repository;
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();

  bool _isCheckingEligibility = true;
  RatingEligibility? _eligibility;

  // Selected ratings
  int _overallRating = 5;
  int _mandiKnowledge = 5;
  int _promptness = 5;
  int _settlement = 5;
  int _communication = 5;

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isSuccess = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SellerRatingsRepository();
    _checkEligibility();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _checkEligibility() async {
    setState(() => _isCheckingEligibility = true);
    try {
      final eligibility = await _repository.checkRatingEligibility(
        brokerId: widget.brokerId,
        dealId: widget.dealId,
      );

      if (!mounted) return;

      if (eligibility.existingRating != null) {
        final r = eligibility.existingRating!;
        _overallRating = r.rating;
        _mandiKnowledge = r.mandiKnowledgeRating;
        _promptness = r.promptnessRating;
        _settlement = r.settlementRating;
        _communication = r.communicationRating;
        _feedbackController.text = r.feedback;
        _isEditing = true;
      }

      setState(() {
        _eligibility = eligibility;
        _isCheckingEligibility = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to check rating eligibility: $e';
        _isCheckingEligibility = false;
      });
    }
  }

  void _showConfirmationDialog() {
    if (_feedbackController.text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback cannot exceed 500 characters.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(LucideIcons.star, color: AppColors.secondary, size: 22),
            const SizedBox(width: 8),
            Text(_isEditing ? 'Confirm Review Update' : 'Confirm Broker Rating', style: AppTypography.titleMedium),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Broker Desk: ${widget.brokerName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              if (widget.dealReference != null) ...[
                const SizedBox(height: 4),
                Text('Linked Trade: ${widget.dealReference}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
              ],
              const Divider(height: 18),
              _buildReviewRow('Overall Rating', '$_overallRating / 5 Stars'),
              _buildReviewRow('Mandi Knowledge', '$_mandiKnowledge / 5'),
              _buildReviewRow('Promptness & Dispatch', '$_promptness / 5'),
              _buildReviewRow('Settlement Timeliness', '$_settlement / 5'),
              _buildReviewRow('Communication', '$_communication / 5'),
              if (_feedbackController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Written Feedback:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    _feedbackController.text.trim(),
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Edit Details'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _submitRating();
            },
            child: const Text('Submit Rating'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRating() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final rating = BrokerRating(
        id: _eligibility?.existingRating?.id ?? 'RAT-${DateTime.now().millisecondsSinceEpoch}',
        brokerId: widget.brokerId,
        brokerName: widget.brokerName,
        sellerId: '', // populated securely by repository from session
        dealId: widget.dealId ?? _eligibility?.eligibleDealId,
        dealReference: widget.dealReference ?? _eligibility?.eligibleDealReference,
        rating: _overallRating,
        mandiKnowledgeRating: _mandiKnowledge,
        promptnessRating: _promptness,
        settlementRating: _settlement,
        communicationRating: _communication,
        feedback: _feedbackController.text.trim(),
        createdAt: _eligibility?.existingRating?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repository.submitBrokerRating(rating);

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });

      // Show brief success toast
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Broker rating updated successfully.' : 'Broker rating submitted successfully.'),
          backgroundColor: AppColors.success,
        ),
      );

      // Return to previous screen after short delay
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) context.pop(true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Broker Rating' : 'Rate Broker Desk'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isCheckingEligibility) {
      return const AppLoadingIndicator(message: 'Verifying trade rating eligibility...');
    }

    if (_eligibility != null && !_eligibility!.isEligible) {
      return _buildIneligibleView();
    }

    if (_isSuccess) {
      return _buildSuccessView();
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Broker & Deal Header Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        widget.brokerName.isNotEmpty ? widget.brokerName[0].toUpperCase() : 'B',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.brokerName, style: AppTypography.titleMedium),
                          const SizedBox(height: 2),
                          const Text('Licensed Mandi Broker Desk', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.dealReference != null || _eligibility?.eligibleDealReference != null) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(LucideIcons.fileCheck, size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(
                        'Verified Trade: ${widget.dealReference ?? _eligibility?.eligibleDealReference}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Primary Star Rating Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Overall Desk Rating', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('Tap a star to rate your overall commercial satisfaction', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      final isSelected = starValue <= _overallRating;
                      return IconButton(
                        iconSize: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        icon: Icon(
                          isSelected ? Icons.star : Icons.star_border,
                          color: isSelected ? Colors.amber.shade600 : Colors.grey.shade400,
                        ),
                        onPressed: () {
                          setState(() => _overallRating = starValue);
                        },
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _getRatingLabel(_overallRating),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _overallRating >= 4 ? Colors.amber.shade800 : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Qualitative Category Ratings Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detailed Trading Criteria', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 12),
                _buildCriterionSelector(
                  label: 'Mandi Rate Discovery & Market Knowledge',
                  value: _mandiKnowledge,
                  onChanged: (val) => setState(() => _mandiKnowledge = val),
                ),
                const Divider(height: 16),
                _buildCriterionSelector(
                  label: 'Promptness & Loading Coordination',
                  value: _promptness,
                  onChanged: (val) => setState(() => _promptness = val),
                ),
                const Divider(height: 16),
                _buildCriterionSelector(
                  label: 'Payment & Settlement Timeliness',
                  value: _settlement,
                  onChanged: (val) => setState(() => _settlement = val),
                ),
                const Divider(height: 16),
                _buildCriterionSelector(
                  label: 'Communication & Term Transparency',
                  value: _communication,
                  onChanged: (val) => setState(() => _communication = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Feedback & Comments Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Written Feedback & Suggestions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                const Text(
                  'Share details on mandi arrival coordination, weighing slip accuracy, or dispatch speed (Optional).',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _feedbackController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'e.g. Accurate weighbridge slips, trucks arrived promptly on loading date...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Counterparty Shield Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.shieldCheck, size: 16, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Counterparty Shield: Direct buyer contact and identification are strictly shielded. Reviews are attributed to verified sellers only.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Error Message Display
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.error)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Submit Action Button
          AppButton(
            label: _isSubmitting
                ? 'Submitting Rating...'
                : (_isEditing ? 'Update Broker Rating' : 'Submit Broker Rating'),
            icon: LucideIcons.send,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _showConfirmationDialog,
            variant: ButtonVariant.primary,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCriterionSelector({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          children: List.generate(5, (index) {
            final star = index + 1;
            final isFilled = star <= value;
            return InkWell(
              onTap: () => onChanged(star),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Icon(
                  isFilled ? Icons.star : Icons.star_border,
                  size: 24,
                  color: isFilled ? Colors.amber.shade600 : Colors.grey.shade400,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildIneligibleView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.lock, size: 40, color: Colors.amber.shade800),
            ),
            const SizedBox(height: 18),
            Text('Rating Locked', style: AppTypography.titleLarge),
            const SizedBox(height: 10),
            Text(
              _eligibility?.reason ?? 'Rating unavailable for this broker.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, height: 1.4),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Return to Broker Profile',
              icon: LucideIcons.arrowLeft,
              variant: ButtonVariant.outline,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.successContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.checkCheck, size: 48, color: AppColors.success),
            ),
            const SizedBox(height: 20),
            Text(
              _isEditing ? 'Rating Updated Successfully!' : 'Rating Submitted Successfully!',
              style: AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your verified trade feedback has been persisted and incorporated into the Mandi Broker Trust Layer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 5:
        return '5 Stars — Exceptional Mandi Trading Desk';
      case 4:
        return '4 Stars — Very Good Service & Rate Discovery';
      case 3:
        return '3 Stars — Average Mandi Execution';
      case 2:
        return '2 Stars — Below Expectations / Delays';
      case 1:
        return '1 Star — Poor Performance';
      default:
        return '$rating Stars';
    }
  }
}
