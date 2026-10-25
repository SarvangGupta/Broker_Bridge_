import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../data/search_repository.dart';
import '../domain/broker_model.dart';
import '../../../l10n/app_localizations.dart';

/// Screen presenting verified broker desk profile details and supported contact actions.
/// Enforces Counterparty Shield: seller identities and direct contact are never permitted.
class BrokerProfileScreen extends StatefulWidget {
  final String brokerId;
  final BrokerModel? initialBroker;
  final SearchRepository? searchRepository;
  final ContactLauncherService? contactLauncher;

  const BrokerProfileScreen({
    super.key,
    required this.brokerId,
    this.initialBroker,
    this.searchRepository,
    this.contactLauncher,
  });

  @override
  State<BrokerProfileScreen> createState() => _BrokerProfileScreenState();
}

class _BrokerProfileScreenState extends State<BrokerProfileScreen> {
  late final SearchRepository _searchRepo;
  late final ContactLauncherService _launcher;
  BrokerModel? _broker;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchRepo = widget.searchRepository ?? SearchRepository();
    _launcher = widget.contactLauncher ?? ContactLauncherService();

    if (widget.initialBroker != null) {
      _broker = widget.initialBroker;
      _isLoading = false;
    } else {
      _loadBroker();
    }
  }

  Future<void> _loadBroker() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final broker = await _searchRepo.getBrokerById(widget.brokerId);
      if (!mounted) return;

      if (broker == null) {
        setState(() {
          _errorMessage = 'Broker profile not found or no longer authorized.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _broker = broker;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load broker profile. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(Tr.titleBrokerProfile)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingIndicator(message: 'Loading authorized broker profile...');
    }

    if (_errorMessage != null || _broker == null) {
      return AppErrorState(
        message: _errorMessage ?? 'Broker profile unavailable',
        onRetry: _loadBroker,
      );
    }

    final broker = _broker!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Broker Identity Header Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          broker.name.isNotEmpty ? broker.name[0].toUpperCase() : 'B',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            broker.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            broker.companyName ?? 'Licensed Mandi Desk',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'AUTHORIZED MANDI BROKER',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                _buildInfoRow('Operating Mandi', broker.location ?? 'State Mandi Floor'),
                _buildInfoRow('Trust Score', '${broker.trustScore} / 100 Verified'),
                if (broker.companyGst != null)
                  _buildInfoRow('Registered GSTIN', broker.companyGst!),
                _buildInfoRow(
                  'Verification Status',
                  broker.isVerified ? 'GST Verified Mandi Desk' : 'Standard License',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Commodities Handled Card
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.package, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Commodities Handled',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: broker.commoditiesHandled.map((commodity) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Text(
                        commodity,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Contact Actions Card
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Broker Communication Actions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Reach out directly to this verified broker to inquire on mandi arrival volumes and quote indications.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                if (broker.hasPhone || broker.hasWhatsApp) ...[
                  Row(
                    children: [
                      if (broker.hasPhone)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _launcher.launchCall(broker.mobile!),
                            icon: const Icon(LucideIcons.phone, size: 16),
                            label: const Text('Call Desk'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      if (broker.hasPhone && broker.hasWhatsApp)
                        const SizedBox(width: 10),
                      if (broker.hasWhatsApp)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _launcher.launchWhatsApp(
                              broker.mobile!,
                              prefilledMessage:
                                  'Hello ${broker.name}, I am contacting you via RMBuyer regarding commodity procurement.',
                            ),
                            icon: const Icon(LucideIcons.messageCircle, size: 16),
                            label: const Text('WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.info, size: 16, color: AppColors.textMutedLight),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Direct phone contact details pending administrative verification. You can post a requirement directly to this desk.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Primary Post Requirement Action
          AppButton(
            label: 'Post Requirement to this Broker Desk',
            onPressed: () {
              final defaultComm = broker.commoditiesHandled.isNotEmpty
                  ? broker.commoditiesHandled.first
                  : '';
              context.push(
                '/requirements/new?brokerId=${Uri.encodeComponent(broker.id)}&brokerName=${Uri.encodeComponent(broker.name)}&commodity=${Uri.encodeComponent(defaultComm)}',
              );
            },
            variant: AppButtonVariant.primary,
            icon: LucideIcons.filePlus,
          ),
          const SizedBox(height: 16),

          // Fiduciary Counterparty Shield Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.shieldCheck, size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Fiduciary Protection: RMBuyer operates on a strict broker-mediated model. All seller offers, counter-bids, and delivery inspections are managed by licensed mandi brokers. Direct seller contacts remain shielded to prevent off-platform transaction exposure.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primaryDark,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
