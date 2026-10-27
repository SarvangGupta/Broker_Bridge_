import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../data/search_repository.dart';
import '../domain/broker_model.dart';
import 'widgets/broker_result_card.dart';

/// Screen presenting verified broker desk profile details and supported contact actions.
/// Only fields present on the authorized broker record are rendered; ratings,
/// experience and deal metrics have no data source yet and are never invented.
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

  /// Guards against duplicate launches or navigation from repeated taps.
  bool _busy = false;

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
        _errorMessage =
            'Unable to load broker profile. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _guarded(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } finally {
      if (mounted) _busy = false;
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final broker = _isLoading || _errorMessage != null ? null : _broker;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Broker Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCw, color: AppColors.primary),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadBroker,
          ),
        ],
      ),
      body: SafeArea(bottom: false, child: _buildBody()),
      // Pinned action; SafeArea keeps it clear of system navigation.
      bottomNavigationBar: broker == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const Key('broker-post-requirement'),
                    onPressed: () => _postRequirement(broker),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.circlePlus, size: 20),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Post Requirement with this Broker',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  /// Opens the existing requirement form with only the broker association;
  /// commodity and commercial terms are left for the buyer to enter.
  void _postRequirement(BrokerModel broker) => _guarded(() async {
    await context.push(
      '/requirements/new',
      extra: <String, dynamic>{
        'brokerId': broker.id,
        'brokerName': broker.name,
        'blankCommercialTerms': true,
      },
    );
  });

  /// Opens this buyer's conversation with the broker; the chat screen finds
  /// an existing thread or shows the new-conversation state.
  void _openChat(BrokerModel broker) => _guarded(() async {
    await context.push('/chats/broker/${broker.id}', extra: broker);
  });

  void _call(BrokerModel broker) => _guarded(() async {
    if (!broker.hasPhone) return _snack(brokerContactPendingMessage);
    final ok = await _launcher.launchCall(broker.mobile!);
    if (!ok && mounted) _snack('Could not open the phone dialer.');
  });

  void _whatsApp(BrokerModel broker) => _guarded(() async {
    if (!broker.hasWhatsApp) return _snack(brokerContactPendingMessage);
    final ok = await _launcher.launchWhatsApp(
      broker.mobile!,
      prefilledMessage:
          'Hello ${broker.name}, I am contacting you via RMBuyer regarding commodity procurement.',
    );
    if (!ok && mounted) _snack('Could not open WhatsApp.');
  });

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingIndicator(
        message: 'Loading authorized broker profile...',
      );
    }

    if (_errorMessage != null || _broker == null) {
      return AppErrorState(
        message: _errorMessage ?? 'Broker profile unavailable',
        onRetry: _loadBroker,
      );
    }

    final broker = _broker!;
    final location = brokerDisplayLocation(broker);
    final firm = brokerFirmName(broker);
    final commodities = brokerCommodities(broker);
    final gst = broker.companyGst?.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildIdentityCard(broker, firm),
          _buildMetricsNote(),
          _section(
            icon: LucideIcons.building2,
            title: 'About This Broker',
            children: [
              if (firm != null)
                _aboutRow(LucideIcons.building, 'Business Name', firm),
              _aboutRow(LucideIcons.user, 'Contact Person', broker.name),
              _aboutRow(
                LucideIcons.shieldCheck,
                'Verification Status',
                broker.isVerified ? 'Verified Broker' : 'Not verified',
                valueColor: broker.isVerified
                    ? AppColors.success
                    : AppColors.textSecondaryLight,
                last: gst == null || gst.isEmpty,
              ),
              if (gst != null && gst.isNotEmpty)
                _aboutRow(
                  LucideIcons.fileText,
                  'GST Registration',
                  gst,
                  last: true,
                ),
            ],
          ),
          _section(
            icon: LucideIcons.sprout,
            title: 'Deals In (Commodities)',
            children: [
              if (commodities.isEmpty)
                const Text(
                  'No commodities listed for this broker yet.',
                  key: Key('broker-no-commodities'),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in commodities) CommodityChip(label: c),
                  ],
                ),
            ],
          ),
          if (location != null)
            _section(
              icon: LucideIcons.mapPin,
              title: 'Location',
              children: [
                _aboutRow(LucideIcons.mapPin, 'Location', location, last: true),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard(BrokerModel broker, String? firm) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BrokerAvatar(broker: broker, size: 68),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      broker.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    if (firm != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        firm,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        broker.isVerified
                            ? const VerifiedBadge(label: 'Verified Broker')
                            : const UnverifiedBadge(),
                        if (broker.showsTrustScore)
                          TrustBadge(score: broker.trustScore),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _iconAction(
                key: const Key('broker-call'),
                icon: LucideIcons.phone,
                label: 'Call broker',
                enabled: broker.hasPhone,
                color: AppColors.primary,
                onTap: () => _call(broker),
              ),
              _iconAction(
                key: const Key('broker-whatsapp'),
                icon: LucideIcons.messageCircle,
                label: 'WhatsApp broker',
                enabled: broker.hasWhatsApp,
                color: AppColors.primary,
                onTap: () => _whatsApp(broker),
              ),
              _iconAction(
                key: const Key('broker-chat'),
                icon: LucideIcons.messagesSquare,
                label: 'Chat with broker',
                enabled: true,
                color: AppColors.info,
                onTap: () => _openChat(broker),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Icon-only circular action. Disabled actions stay visible but muted and
  /// explain themselves on tap.
  Widget _iconAction({
    required Key key,
    required IconData icon,
    required String label,
    required bool enabled,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: enabled ? label : '$label (unavailable)',
      child: Semantics(
        button: true,
        enabled: enabled,
        label: enabled ? label : '$label unavailable',
        excludeSemantics: true,
        child: Material(
          key: key,
          color: enabled ? color : AppColors.borderLight,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                icon,
                size: 24,
                color: enabled ? Colors.white : AppColors.textMutedLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Ratings, experience, deal and client metrics have no backend source yet.
  Widget _buildMetricsNote() {
    return Container(
      key: const Key('broker-metrics-unavailable'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Row(
        children: [
          Icon(LucideIcons.star, size: 18, color: AppColors.textMutedLight),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ratings, reviews and trade history are not available yet.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _aboutRow(
    IconData icon,
    String label,
    String value, {
    Color valueColor = AppColors.textPrimaryLight,
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondaryLight),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
