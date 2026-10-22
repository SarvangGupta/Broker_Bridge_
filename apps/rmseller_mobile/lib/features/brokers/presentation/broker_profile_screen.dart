import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../ratings/data/seller_ratings_repository.dart';
import '../../ratings/domain/broker_rating_model.dart';
import '../data/seller_broker_repository.dart';
import '../domain/seller_broker_model.dart';

class BrokerProfileScreen extends StatefulWidget {
  final String brokerId;
  final SellerBrokerModel? initialBroker;

  const BrokerProfileScreen({
    super.key,
    required this.brokerId,
    this.initialBroker,
  });

  @override
  State<BrokerProfileScreen> createState() => _BrokerProfileScreenState();
}

class _BrokerProfileScreenState extends State<BrokerProfileScreen> {
  final SellerBrokerRepository _repository = SellerBrokerRepository();
  final SellerRatingsRepository _ratingsRepository = SellerRatingsRepository();
  final ContactLauncherService _contactLauncher =
      const ContactLauncherService();

  SellerBrokerModel? _broker;
  BrokerRatingSummary? _ratingSummary;
  bool _isLoading = true;
  bool _isLoadingRatings = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialBroker != null) {
      _broker = widget.initialBroker;
      _isLoading = false;
      _loadRatings();
    } else {
      _loadBroker();
    }
  }

  Future<void> _loadBroker() async {
    setState(() => _isLoading = true);
    final b = await _repository.getBrokerById(widget.brokerId);
    if (!mounted) return;
    setState(() {
      _broker = b;
      _isLoading = false;
    });
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    setState(() => _isLoadingRatings = true);
    final summary = await _ratingsRepository.getBrokerRatingSummary(
      widget.brokerId,
      fallbackTrustScore: _broker?.trustScore ?? 100,
    );
    if (!mounted) return;
    setState(() {
      _ratingSummary = summary;
      _isLoadingRatings = false;
    });
  }

  Future<void> _handleRateBroker() async {
    final broker = _broker;
    if (broker == null) return;

    // Check eligibility
    final eligibility = await _ratingsRepository.checkRatingEligibility(
      brokerId: broker.id,
    );

    if (!mounted) return;

    if (!eligibility.isEligible && !eligibility.hasAlreadyRated) {
      // Show ineligibility explanation dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(LucideIcons.lock, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Rating Unavailable',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Text(
            eligibility.reason,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    // Navigate to RateBrokerScreen and reload ratings on return
    final result = await context.push(
      '/brokers/${broker.id}/rate',
      extra: {
        'brokerName': broker.name,
        'dealId': eligibility.eligibleDealId,
        'dealReference': eligibility.eligibleDealReference,
      },
    );

    if (result == true) {
      _loadRatings();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppLoadingIndicator(message: 'Loading broker profile...'),
      );
    }

    if (_broker == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Broker Profile')),
        body: const Center(child: Text('Broker profile not found')),
      );
    }

    final broker = _broker!;
    final summary = _ratingSummary;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Broker Trading Desk'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () {
              _loadBroker();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header Card
          AppCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    broker.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(broker.name, style: AppTypography.titleLarge),
                    if (broker.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        LucideIcons.badgeCheck,
                        size: 20,
                        color: AppColors.success,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  broker.companyName ?? 'Licensed Mandi Desk',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.shieldCheck,
                            size: 14,
                            color: AppColors.secondaryDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Trust Score: ${broker.trustScore}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (summary != null && !summary.isUnrated) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${summary.averageRating.toStringAsFixed(1)} ★ (${summary.totalReviews})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mandi Broker Ratings & Review Breakdown Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Broker Ratings & Reviews',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (summary?.hasUserReviewed ?? false)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.check,
                              size: 11,
                              color: AppColors.success,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'You Reviewed',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingRatings) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ] else if (summary != null && !summary.isUnrated) ...[
                  // Rating Overview Score & Distribution Bars
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Score Column
                      Column(
                        children: [
                          Text(
                            summary.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (index) {
                              final starVal = index + 1;
                              return Icon(
                                starVal <= summary.averageRating.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 16,
                                color: Colors.amber.shade600,
                              );
                            }),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${summary.totalReviews} verified reviews',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Distribution Bars
                      Expanded(
                        child: Column(
                          children: [5, 4, 3, 2, 1].map((star) {
                            final pct = summary.getPercentage(star);
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 1.5,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '$star★',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: pct,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              star >= 4
                                                  ? Colors.amber.shade600
                                                  : (star == 3
                                                        ? Colors.amber.shade400
                                                        : AppColors.error),
                                            ),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${summary.starDistribution[star] ?? 0}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Criteria Breakdown
                  const Text(
                    'Criteria Performance',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ...summary.criteriaAverages.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${entry.value.toStringAsFixed(1)} / 5',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.star,
                                size: 12,
                                color: Colors.amber.shade600,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  // Unrated state
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          LucideIcons.info,
                          size: 18,
                          color: AppColors.textSecondaryLight,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Unrated Desk — This broker has not yet received trade reviews from sellers. Be the first to rate after completing a transaction.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Rate / Edit Review Action Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleRateBroker,
                    icon: Icon(
                      summary?.hasUserReviewed ?? false
                          ? LucideIcons.edit3
                          : LucideIcons.star,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      summary?.hasUserReviewed ?? false
                          ? 'Update Your Review'
                          : 'Rate this Broker Desk',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recent Verified Reviews List
          if (summary != null && summary.recentReviews.isNotEmpty) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verified Trade Feedback',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  ...summary.recentReviews.map((r) {
                    final dateFormat = DateFormat('dd MMM yyyy');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    LucideIcons.badgeCheck,
                                    size: 14,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Verified Mandi Seller',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                dateFormat.format(r.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: List.generate(5, (idx) {
                              return Icon(
                                idx < r.rating ? Icons.star : Icons.star_border,
                                size: 14,
                                color: Colors.amber.shade600,
                              );
                            }),
                          ),
                          if (r.feedback.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              r.feedback,
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Desk Details
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mandi Trading Credentials',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  'Operating Mandi:',
                  broker.location ?? 'Regional Mandi',
                ),
                if (broker.companyGst != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow('GST Registration:', broker.companyGst!),
                ],
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Verification Status:',
                  broker.isVerified
                      ? 'Verified Licensed Broker'
                      : 'Pending Audit',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Commodities Handled
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Specialized Mandi Commodities',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: broker.commoditiesHandled.map((c) {
                    return Chip(
                      label: Text(c, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.borderLight),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Communication Actions
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Direct Broker Communication',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Reach out directly to this licensed broker desk to discuss mandi pricing, lot matching, or dispatch scheduling.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (broker.hasPhone)
                      Expanded(
                        child: AppButton(
                          label: 'Call Desk',
                          icon: LucideIcons.phone,
                          onPressed: () =>
                              _contactLauncher.launchPhone(broker.mobile),
                          variant: ButtonVariant.outline,
                        ),
                      ),
                    if (broker.hasPhone && broker.hasWhatsApp)
                      const SizedBox(width: 12),
                    if (broker.hasWhatsApp)
                      Expanded(
                        child: AppButton(
                          label: 'WhatsApp',
                          icon: LucideIcons.messageCircle,
                          onPressed: () => _contactLauncher.launchWhatsApp(
                            broker.mobile,
                            defaultMessage:
                                'Hello ${broker.name}, I would like to consult on my commodity lots.',
                          ),
                          variant: ButtonVariant.secondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Broker Chat & Commission Desk
          AppButton(
            label: 'Broker Chat & Commission Desk',
            icon: LucideIcons.messageSquare,
            onPressed: () {
              context.push('/communication/broker/${broker.id}', extra: broker);
            },
            variant: ButtonVariant.primary,
          ),
          const SizedBox(height: 12),

          // Post with this Broker Shortcut
          AppButton(
            label: '+ Post Commodity with this Broker Desk',
            icon: LucideIcons.plusCircle,
            onPressed: () {
              context.push(
                '/commodities/new?brokerId=${broker.id}&brokerName=${Uri.encodeComponent(broker.name)}',
              );
            },
            variant: ButtonVariant.outline,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryLight,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }
}
