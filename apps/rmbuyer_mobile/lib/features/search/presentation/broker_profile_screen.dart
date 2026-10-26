import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/widgets/app_button.dart';
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
    final broker = _isLoading || _errorMessage != null ? null : _broker;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(context.tr(Tr.titleBrokerProfile)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: _buildBody(),
      ),
      // Pinned primary action; SafeArea keeps it clear of system navigation.
      bottomNavigationBar: broker == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: AppButton(
                  label: 'Post Requirement to Broker',
                  onPressed: () => _postRequirement(broker),
                  variant: AppButtonVariant.primary,
                  icon: LucideIcons.filePlus,
                ),
              ),
            ),
    );
  }

  void _postRequirement(BrokerModel broker) {
    final defaultComm = broker.hasCommodityData && broker.commoditiesHandled.isNotEmpty
        ? broker.commoditiesHandled.first
        : '';
    context.push(
      '/requirements/new?brokerId=${Uri.encodeComponent(broker.id)}&brokerName=${Uri.encodeComponent(broker.name)}&commodity=${Uri.encodeComponent(defaultComm)}',
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
    final commodities = broker.hasCommodityData ? broker.commoditiesHandled : const <String>[];
    final company = broker.companyName?.trim();
    final hasCompany = company != null &&
        company.isNotEmpty &&
        company != 'Licensed Mandi Broker Desk' &&
        company != 'Licensed Mandi Desk';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header + contact actions
          _section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(LucideIcons.briefcase, size: 28, color: AppColors.primary),
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                          if (hasCompany) ...[
                            const SizedBox(height: 2),
                            Text(
                              company,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                            ),
                          ],
                          if (location != null) ...[
                            const SizedBox(height: 6),
                            _metaLine(LucideIcons.mapPin, location),
                          ],
                          if (broker.isVerified) ...[
                            const SizedBox(height: 6),
                            _metaLine(LucideIcons.badgeCheck, 'Verified profile', color: AppColors.success),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildContactRow(broker),
              ],
            ),
          ),

          if (commodities.isNotEmpty)
            _section(
              child: _chipSection(LucideIcons.package, 'Commodities Dealt In', commodities),
            ),

          if (location != null)
            _section(
              child: _chipSection(LucideIcons.mapPin, 'Markets Served', [location]),
            ),

          // Credibility: only metrics backed by existing data
          _section(
            color: AppColors.successBackground.withValues(alpha: 0.45),
            borderColor: AppColors.success.withValues(alpha: 0.15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(LucideIcons.chartColumn, 'Credibility & Experience'),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _metric(LucideIcons.shieldCheck, '${broker.trustScore} / 100', 'Trust Score'),
                      const VerticalDivider(width: 1),
                      _metric(
                        broker.isVerified ? LucideIcons.badgeCheck : LucideIcons.fileText,
                        broker.isVerified ? 'GST Verified' : 'Standard',
                        'Verification',
                      ),
                    ],
                  ),
                ),
                if (broker.companyGst != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Registered GSTIN: ${broker.companyGst}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                  ),
                ],
              ],
            ),
          ),

          // Counterparty Shield Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.shieldCheck, size: 22, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All negotiations remain broker-mediated. Seller identities stay protected.',
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

  Widget _buildContactRow(BrokerModel broker) {
    if (!broker.hasPhone && !broker.hasWhatsApp) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
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
      );
    }

    return Row(
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
    );
  }

  Widget _section({required Widget child, Color? color, Color? borderColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AppColors.borderLight),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipSection(IconData icon, String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(icon, title),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimaryLight),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaLine(IconData icon, String text, {Color color = AppColors.textSecondaryLight}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ),
      ],
    );
  }

  Widget _metric(IconData icon, String value, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
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
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: color),
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
}
