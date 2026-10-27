import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/contact_launcher_service.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/broker_model.dart';

/// Placeholder values the broker model substitutes when data is missing;
/// they carry no information, so directory and profile views hide them.
const _placeholderLocation = 'Mandi Trading Floor';
const _placeholderFirms = {'Licensed Mandi Broker Desk', 'Licensed Mandi Desk'};

/// Real broker location, or null when only the model's placeholder is present.
String? brokerDisplayLocation(BrokerModel broker) {
  final loc = broker.location?.trim();
  if (loc == null || loc.isEmpty || loc == _placeholderLocation) return null;
  return loc;
}

/// Real firm/business name, or null when only the model's placeholder is present.
String? brokerFirmName(BrokerModel broker) {
  final firm = broker.companyName?.trim();
  if (firm == null || firm.isEmpty || _placeholderFirms.contains(firm)) return null;
  return firm;
}

/// Commodities from the data source; empty when the model substituted defaults.
List<String> brokerCommodities(BrokerModel broker) =>
    broker.hasCommodityData ? broker.commoditiesHandled : const [];

const _avatarPalette = [
  (Color(0xFFE2F3EC), Color(0xFF0F7A55)),
  (Color(0xFFFDE7E7), Color(0xFFB4232F)),
  (Color(0xFFFFF1DD), Color(0xFFB66A12)),
  (Color(0xFFE6EEFC), Color(0xFF2856B8)),
  (Color(0xFFF0E9FB), Color(0xFF6D3FC0)),
];

/// Circular initial avatar with a stable per-broker tint.
class BrokerAvatar extends StatelessWidget {
  final BrokerModel broker;
  final double size;

  const BrokerAvatar({super.key, required this.broker, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _avatarPalette[broker.id.hashCode.abs() % _avatarPalette.length];
    final initial = broker.name.trim().isNotEmpty ? broker.name.trim()[0].toUpperCase() : 'B';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Shown when a contact action is unavailable for a broker.
const brokerContactPendingMessage =
    'Contact details for this broker are pending verification.';

/// Directory card for an authorized broker: identity, real attributes and
/// Call / WhatsApp / Chat actions. Only data present in the source row is
/// rendered; missing values are hidden, never substituted.
/// Strictly enforces Counterparty Shield: seller identities are never rendered.
class BrokerResultCard extends StatefulWidget {
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
  State<BrokerResultCard> createState() => _BrokerResultCardState();
}

class _BrokerResultCardState extends State<BrokerResultCard> {
  late ContactLauncherService _launcher;

  /// Guards against duplicate navigation or launches from repeated taps.
  bool _busy = false;

  BrokerModel get broker => widget.broker;

  @override
  void initState() {
    super.initState();
    _launcher = widget.contactLauncher ?? ContactLauncherService();
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

  void _openProfile() => _guarded(() async {
        if (widget.onTap != null) {
          widget.onTap!();
          return;
        }
        await context.push('/brokers/${broker.id}', extra: broker);
      });

  void _chat() => _guarded(() async {
        await context.push('/chats/broker/${broker.id}', extra: broker);
      });

  void _call() => _guarded(() async {
        if (!broker.hasPhone) return _snack(brokerContactPendingMessage);
        final ok = await _launcher.launchCall(broker.mobile!);
        if (!ok && mounted) _snack('Could not open the phone dialer.');
      });

  void _whatsApp() => _guarded(() async {
        if (!broker.hasWhatsApp) return _snack(brokerContactPendingMessage);
        final ok = await _launcher.launchWhatsApp(
          broker.mobile!,
          prefilledMessage:
              'Hello ${broker.name}, I am contacting you via RMBuyer regarding commodity procurement.',
        );
        if (!ok && mounted) _snack('Could not open WhatsApp.');
      });

  @override
  Widget build(BuildContext context) {
    final location = brokerDisplayLocation(broker);
    final firm = brokerFirmName(broker);
    final commodities = brokerCommodities(broker);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      onTap: _openProfile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BrokerAvatar(broker: broker, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          broker.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        broker.isVerified
                            ? const VerifiedBadge(label: 'Verified Broker')
                            : const UnverifiedBadge(),
                      ],
                    ),
                    if (firm != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        firm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                    if (broker.showsTrustScore) ...[
                      const SizedBox(height: 6),
                      TrustBadge(score: broker.trustScore),
                    ],
                    if (location != null) ...[
                      const SizedBox(height: 6),
                      _metaRow(LucideIcons.mapPin, location),
                    ],
                    if (commodities.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _metaRow(LucideIcons.sprout, commodities.join(', ')),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),
          Row(
            children: [
              _action(
                key: const Key('card-call'),
                icon: LucideIcons.phone,
                label: 'Call',
                enabled: broker.hasPhone,
                fg: AppColors.primary,
                bg: AppColors.successBackground,
                onTap: _call,
              ),
              const SizedBox(width: 8),
              _action(
                key: const Key('card-whatsapp'),
                icon: LucideIcons.messageCircle,
                label: 'WhatsApp',
                enabled: broker.hasWhatsApp,
                fg: AppColors.primary,
                bg: AppColors.successBackground,
                onTap: _whatsApp,
              ),
              const SizedBox(width: 8),
              _action(
                key: const Key('card-chat'),
                icon: LucideIcons.messagesSquare,
                label: 'Chat',
                enabled: true,
                fg: AppColors.info,
                bg: AppColors.infoBackground,
                onTap: _chat,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: AppColors.textMutedLight),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ),
      ],
    );
  }

  /// Equal-width contact action. A disabled action stays visible (muted) and
  /// explains itself on tap instead of launching anything.
  Widget _action({
    required Key key,
    required IconData icon,
    required String label,
    required bool enabled,
    required Color fg,
    required Color bg,
    required VoidCallback onTap,
  }) {
    final color = enabled ? fg : AppColors.textMutedLight;
    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: enabled ? label : '$label unavailable',
        excludeSemantics: true,
        child: Material(
          key: key,
          color: enabled ? bg : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Neutral grey pill for brokers whose company is not verified (or unknown).
class UnverifiedBadge extends StatelessWidget {
  const UnverifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.shield, size: 12, color: AppColors.textMutedLight),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              'Unverified Broker',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Green "Verified" pill, shown only when the data source confirms verification.
class VerifiedBadge extends StatelessWidget {
  final String label;

  const VerifiedBadge({super.key, this.label = 'Verified'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.successBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.badgeCheck, size: 12, color: AppColors.success),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}

/// Trust-score pill shared by the directory card and broker profile.
class TrustBadge extends StatelessWidget {
  final int score;
  final bool compact;

  const TrustBadge({super.key, required this.score, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.shieldCheck, size: 12, color: AppColors.warning),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              compact ? '$score%' : 'Trust Score: $score%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small outlined commodity tag.
class CommodityChip extends StatelessWidget {
  final String label;
  final bool highlighted;

  const CommodityChip({super.key, required this.label, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.successBackground : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlighted ? Colors.transparent : AppColors.borderLight),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: highlighted ? AppColors.success : AppColors.textPrimaryLight,
        ),
      ),
    );
  }
}
