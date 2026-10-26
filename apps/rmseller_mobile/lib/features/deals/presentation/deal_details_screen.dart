import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../../brokers/data/seller_broker_repository.dart';
import '../../brokers/domain/seller_broker_model.dart';
import '../data/seller_deals_repository.dart';
import '../domain/seller_deal_model.dart';
import 'deal_section_details_screens.dart';

class DealDetailsScreen extends StatefulWidget {
  final String dealId;
  final SellerDealModel? initialDeal;
  final SellerBrokerRepository? brokerRepository;

  const DealDetailsScreen({
    super.key,
    required this.dealId,
    this.initialDeal,
    this.brokerRepository,
  });

  @override
  State<DealDetailsScreen> createState() => _DealDetailsScreenState();
}

class _DealDetailsScreenState extends State<DealDetailsScreen> {
  final SellerDealsRepository _repository = SellerDealsRepository();
  late final SellerBrokerRepository _brokerRepository;
  final ContactLauncherService _contactLauncher =
      const ContactLauncherService();

  SellerDealModel? _deal;
  SellerBrokerModel? _broker;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _brokerRepository = widget.brokerRepository ?? SellerBrokerRepository();
    if (widget.initialDeal != null) {
      _deal = widget.initialDeal;
      _isLoading = false;
      _loadBroker();
    } else {
      _loadDeal();
    }
  }

  Future<void> _loadDeal() async {
    setState(() => _isLoading = true);
    final item = await _repository.getDealById(widget.dealId);
    if (!mounted) return;
    setState(() {
      _deal = item;
      _isLoading = false;
    });
    _loadBroker();
  }

  /// Resolves the mediating broker's real contact details from the seller's
  /// broker list. Contact actions stay disabled when no record is found.
  Future<void> _loadBroker() async {
    final brokerId = _deal?.brokerId;
    if (brokerId == null) return;
    try {
      final broker = await _brokerRepository.getBrokerById(brokerId);
      if (!mounted) return;
      setState(() => _broker = broker);
    } catch (_) {
      // Leave contact actions disabled.
    }
  }

  void _openCommissionChat(SellerDealModel deal) {
    final brokerId = deal.brokerId ?? 'BRK-DEFAULT';
    context.push('/communication/broker/$brokerId');
  }

  void _openInvoice(SellerDealModel deal) {
    context.push('/invoices/${deal.invoiceId ?? deal.invoiceNo!}');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppLoadingIndicator(
          message: 'Loading deal contract & invoices...',
        ),
      );
    }

    if (_deal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Deal Details')),
        body: const Center(child: Text('Deal not found or inaccessible.')),
      );
    }

    final deal = _deal!;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: Text(deal.bookingReference ?? deal.id)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: ElevatedButton.icon(
          key: const Key('deal_commission_chat_button'),
          onPressed: () => _openCommissionChat(deal),
          icon: const Icon(LucideIcons.messageSquare, size: 18),
          label: const Text('Chat with Commission Desk'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          // Commercial Summary Card
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iconBox(LucideIcons.package, AppColors.secondaryDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deal.commodityName,
                            style: AppTypography.titleMedium,
                          ),
                          Text(
                            deal.gradeName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topRight,
                        child: StatusBadge(status: deal.status),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      _metric(
                        'Quantity',
                        '${deal.agreedQuantity} ${deal.unit}',
                      ),
                      const VerticalDivider(width: 12),
                      _metric(
                        'Rate',
                        '₹${deal.agreedPrice.toStringAsFixed(0)} / ${deal.unit}',
                      ),
                      const VerticalDivider(width: 12),
                      _metric(
                        'Total Value',
                        '₹${deal.totalDealValue.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _metric(
                      'Contract Date',
                      dateFormat.format(deal.createdAt),
                      icon: LucideIcons.calendar,
                      small: true,
                    ),
                    if (deal.bookingReference != null) ...[
                      const SizedBox(width: 12),
                      _metric(
                        'System Booking ID',
                        deal.bookingReference!,
                        icon: LucideIcons.fileText,
                        small: true,
                      ),
                    ],
                  ],
                ),
                if (deal.closedAt != null) ...[
                  const SizedBox(height: 8),
                  _metric(
                    'Settled Date',
                    dateFormat.format(deal.closedAt!),
                    icon: LucideIcons.calendarCheck,
                    small: true,
                    expand: false,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Invoices & Tax Statements
          _sectionCard(
            key: const Key('deal_invoice_section'),
            icon: LucideIcons.receipt,
            iconColor: AppColors.success,
            title: 'Invoices & Tax Statements',
            trailing: deal.invoiceStatus != null
                ? StatusBadge(status: deal.invoiceStatus!)
                : null,
            onTap: deal.invoiceNo != null ? () => _openInvoice(deal) : null,
            child: deal.invoiceNo != null
                ? Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deal.invoiceNo!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '₹${(deal.invoiceAmount ?? deal.totalDealValue).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('deal_view_invoice_button'),
                        onPressed: () => _openInvoice(deal),
                        icon: const Icon(LucideIcons.fileText, size: 15),
                        label: const Text('View Invoice'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          foregroundColor: AppColors.textPrimaryLight,
                          side: const BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'No invoice generated yet for this deal. Invoices are issued by the mediating broker upon vehicle dispatch.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
          ),
          const SizedBox(height: 10),

          // Broker Commission — summary only; breakdown opens separately
          _sectionCard(
            key: const Key('deal_commission_section'),
            icon: LucideIcons.indianRupee,
            iconColor: AppColors.info,
            title: 'Broker Commission',
            trailing: StatusBadge(status: deal.commissionStatus),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DealCommissionDetailsScreen(deal: deal),
              ),
            ),
            child: deal.commissionRate != null && deal.commissionRate! > 0
                ? IntrinsicHeight(
                    child: Row(
                      children: [
                        _metric(
                          'Rate',
                          '₹${deal.commissionRate!.toStringAsFixed(0)} ${deal.commissionBasis.replaceFirst('₹', '')}',
                          centered: true,
                        ),
                        const VerticalDivider(width: 8),
                        _metric(
                          'Payable',
                          '₹${(deal.commissionAmount ?? 0).toStringAsFixed(0)}',
                          centered: true,
                        ),
                        const VerticalDivider(width: 8),
                        _metric(
                          'Paid',
                          '₹${deal.commissionPaid.toStringAsFixed(0)}',
                          centered: true,
                          color: AppColors.success,
                        ),
                        const VerticalDivider(width: 8),
                        _metric(
                          'Outstanding',
                          '₹${deal.commissionOutstanding.toStringAsFixed(0)}',
                          centered: true,
                          color: deal.commissionOutstanding > 0
                              ? AppColors.error
                              : null,
                        ),
                      ],
                    ),
                  )
                : const Text(
                    'No commission terms recorded for this contract.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
          ),
          const SizedBox(height: 10),

          // Broker Details — broker-mediated; buyer identity stays shielded
          _buildBrokerCard(deal),
          const SizedBox(height: 10),

          // Logistics & Vehicle Entry — summary only; details open separately
          if (deal.vehicleNumber != null) ...[
            _sectionCard(
              key: const Key('deal_logistics_section'),
              icon: LucideIcons.truck,
              iconColor: AppColors.info,
              title: 'Logistics & Vehicle Entry',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DealLogisticsDetailsScreen(deal: deal),
                ),
              ),
              child: Column(
                children: [
                  _summaryRow('Vehicle Registration', deal.vehicleNumber!),
                  if (deal.dispatchDate != null)
                    _summaryRow(
                      'Dispatch Timestamp',
                      dateFormat.format(deal.dispatchDate!),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBrokerCard(SellerDealModel deal) {
    final broker = _broker;
    final canCall = broker != null && broker.hasPhone;
    final canWhatsApp = broker != null && broker.hasWhatsApp;

    return AppCard(
      key: const Key('deal_broker_section'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBox(LucideIcons.user, Colors.purple.shade400),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Broker Details', style: AppTypography.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      deal.brokerDeskName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (broker?.location != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.mapPin,
                              size: 12,
                              color: AppColors.textMutedLight,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                broker!.location!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (broker != null && broker.isRegisteredVerified)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Licensed Broker',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(
                LucideIcons.shieldCheck,
                size: 12,
                color: AppColors.textMutedLight,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Broker-mediated deal. Buyer identity is shielded.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMutedLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _contactIcon(
                key: const Key('deal_broker_call'),
                icon: LucideIcons.phone,
                tooltip: canCall ? 'Call Broker' : 'Broker phone not available',
                color: AppColors.primary,
                onPressed: canCall
                    ? () => _contactLauncher.launchPhone(broker.mobile)
                    : null,
              ),
              const SizedBox(width: 8),
              _contactIcon(
                key: const Key('deal_broker_whatsapp'),
                icon: LucideIcons.messageCircle,
                tooltip: canWhatsApp
                    ? 'WhatsApp'
                    : 'Broker WhatsApp not available',
                color: Colors.green.shade700,
                onPressed: canWhatsApp
                    ? () => _contactLauncher.launchWhatsApp(broker.mobile)
                    : null,
              ),
              const SizedBox(width: 8),
              _contactIcon(
                key: const Key('deal_broker_chat'),
                icon: LucideIcons.messageSquare,
                tooltip: 'Broker Chat',
                color: AppColors.info,
                onPressed: () => _openCommissionChat(deal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('deal_rate_broker_button'),
                  onPressed: () {
                    final brokerId =
                        deal.brokerId ?? 'b354958e-779a-41f2-b7a3-5899eca32e32';
                    context.push(
                      '/brokers/$brokerId/rate',
                      extra: {
                        'brokerName': deal.brokerDeskName,
                        'dealId': deal.id,
                        'dealReference': deal.bookingReference,
                      },
                    );
                  },
                  icon: Icon(
                    LucideIcons.star,
                    size: 15,
                    color: Colors.amber.shade800,
                  ),
                  label: Text(
                    'Rate Broker',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    backgroundColor: Colors.amber.shade50,
                    side: BorderSide(color: Colors.amber.shade200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  /// Card with icon, title, optional trailing badge and a chevron when
  /// [onTap] is set; [child] is the compact summary.
  Widget _sectionCard({
    required Key key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return AppCard(
      key: key,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(icon, iconColor),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: AppTypography.titleSmall)),
              if (trailing != null) ...[trailing, const SizedBox(width: 4)],
              if (onTap != null)
                const Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: AppColors.textSecondaryLight,
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _metric(
    String label,
    String value, {
    IconData? icon,
    Color? color,
    bool small = false,
    bool centered = false,
    bool expand = true,
  }) {
    final content = Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: small ? 13 : 14,
              fontWeight: small ? FontWeight.w600 : FontWeight.w800,
              color: color ?? AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
    final body = icon == null
        ? content
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppColors.textMutedLight),
              const SizedBox(width: 6),
              Flexible(child: content),
            ],
          );
    return expand ? Expanded(child: body) : body;
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactIcon({
    required Key key,
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final effective = onPressed == null ? AppColors.textMutedLight : color;
    return Material(
      color: effective.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: IconButton(
        key: key,
        icon: Icon(icon, size: 18, color: effective),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      ),
    );
  }
}
