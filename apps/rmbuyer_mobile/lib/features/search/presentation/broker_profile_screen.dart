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
import 'widgets/broker_result_card.dart';
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

    final location = brokerDisplayLocation(broker);
    final company = broker.companyName?.trim();
    final hasCompany = company != null &&
        company.isNotEmpty &&
        company != 'Licensed Mandi Broker Desk' &&
        company != 'Licensed Mandi Desk';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Identity header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(LucideIcons.briefcase, size: 26, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              broker.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TrustBadge(score: broker.trustScore),
                        ],
                      ),
                      if (location != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '($location)',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                        ),
                      ],
                      if (broker.commoditiesHandled.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in broker.commoditiesHandled.take(4)) CommodityChip(label: c),
                            if (broker.commoditiesHandled.length > 4)
                              CommodityChip(label: '+${broker.commoditiesHandled.length - 4}'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Contact actions: only rendered when a verified number exists
          if (broker.hasPhone || broker.hasWhatsApp)
            Row(
              children: [
                if (broker.hasPhone)
                  _buildContactAction(
                    key: const Key('broker-call'),
                    icon: LucideIcons.phone,
                    label: 'Call',
                    color: AppColors.info,
                    background: AppColors.infoBackground,
                    onTap: () => _launcher.launchCall(broker.mobile!),
                  ),
                if (broker.hasPhone && broker.hasWhatsApp) const SizedBox(width: 10),
                if (broker.hasWhatsApp)
                  _buildContactAction(
                    key: const Key('broker-whatsapp'),
                    icon: LucideIcons.messageCircle,
                    label: 'WhatsApp',
                    color: const Color(0xFF128C4A),
                    background: const Color(0xFFDCF8E6),
                    onTap: () => _launcher.launchWhatsApp(
                      broker.mobile!,
                      prefilledMessage:
                          'Hello ${broker.name}, I am contacting you via RMBuyer regarding commodity procurement.',
                    ),
                  ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
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
          const SizedBox(height: 20),

          // About
          const Text(
            'About This Broker',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                if (location != null)
                  _buildAboutRow(LucideIcons.mapPin, 'Mandi Location', location),
                if (broker.commoditiesHandled.isNotEmpty)
                  _buildAboutRow(
                    LucideIcons.package,
                    'Deals In',
                    broker.commoditiesHandled.join(', '),
                  ),
                _buildAboutRow(
                  LucideIcons.shieldCheck,
                  'Trust Score',
                  broker.isVerified ? 'GST Verified Mandi Desk' : 'Standard License',
                  trailing: '${broker.trustScore} / 100',
                ),
                if (hasCompany)
                  _buildAboutRow(LucideIcons.building2, 'Broker Desk', company),
                if (broker.companyGst != null)
                  _buildAboutRow(LucideIcons.fileText, 'Registered GSTIN', broker.companyGst!),
              ],
            ),
          ),
          const SizedBox(height: 20),

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
          const SizedBox(height: 14),

          // Counterparty Shield Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.shieldCheck, size: 18, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Seller identities stay protected. Offers, counter-bids and inspections are handled by licensed mandi brokers.',
                    style: TextStyle(fontSize: 12, color: AppColors.primaryDark, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactAction({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        key: key,
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutRow(IconData icon, String label, String value, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.success,
              ),
            ),
        ],
      ),
    );
  }
}
