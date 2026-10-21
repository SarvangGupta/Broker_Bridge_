import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/services/contact_launcher_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../brokers/domain/seller_broker_model.dart';
import '../../commodities/domain/commodity_model.dart';
import '../data/negotiation_repository.dart';
import '../domain/negotiation_model.dart';

class BrokerCommunicationScreen extends StatefulWidget {
  final String requestId;
  final String brokerId;
  final String? brokerName;
  final String? brokerPhone;
  final String? brokerLocation;
  final int? trustScore;
  final String? commodityContext;
  final SellerCommodity? commodity;

  const BrokerCommunicationScreen({
    super.key,
    required this.requestId,
    required this.brokerId,
    this.brokerName,
    this.brokerPhone,
    this.brokerLocation,
    this.trustScore,
    this.commodityContext,
    this.commodity,
  });

  @override
  State<BrokerCommunicationScreen> createState() => _BrokerCommunicationScreenState();
}

class _BrokerCommunicationScreenState extends State<BrokerCommunicationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NegotiationRepository _repository = NegotiationRepository();
  final ContactLauncherService _contactLauncher = const ContactLauncherService();

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  List<BrokerMessage> _messages = [];
  CommissionSummary? _commissionSummary;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    NegotiationRepository.negotiationUpdatedNotifier.addListener(_onDataUpdated);
  }

  @override
  void dispose() {
    NegotiationRepository.negotiationUpdatedNotifier.removeListener(_onDataUpdated);
    _tabController.dispose();
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _onDataUpdated() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    try {
      final msgs = await _repository.getBrokerMessages(widget.requestId);
      final summary = await _repository.getCommissionSummary(widget.requestId);

      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _commissionSummary = summary;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load conversation: $e';
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await _repository.sendMessage(
        requestId: widget.requestId,
        brokerId: widget.brokerId,
        text: text,
      );
      _messageController.clear();
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _openProposeCommissionDialog({bool isCounter = false}) async {
    final rateController = TextEditingController();
    final notesController = TextEditingController();
    String selectedBasis = '₹/MT';

    if (isCounter && _commissionSummary?.latestProposal?.commissionRate != null) {
      rateController.text = _commissionSummary!.latestProposal!.commissionRate!.toStringAsFixed(0);
      selectedBasis = _commissionSummary!.latestProposal!.commissionBasis;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.scale, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        isCounter ? 'Counter Commission Proposal' : 'Propose Commission Rate',
                        style: AppTypography.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Text(
                    'Specify the transparent brokerage compensation for matching this commodity supply lot.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: AppTextField(
                          controller: rateController,
                          label: 'Proposed Commission Rate *',
                          hint: 'e.g. 50',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Commission Calculation Basis *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedBasis,
                              isExpanded: true,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                              items: const [
                                DropdownMenuItem(value: '₹/MT', child: Text('₹/MT (Per Metric Ton)', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: '₹/QTL', child: Text('₹/QTL (Per Quintal)', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: '₹/Bag', child: Text('₹/Bag (Per 50kg Bag)', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: '% of Invoice', child: Text('% of Invoice', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (val) {
                                if (val != null) setSheetState(() => selectedBasis = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  AppTextField(
                    controller: notesController,
                    label: 'Rationale / Commercial Notes (Optional)',
                    hint: 'e.g. Standard rate for 100 MT volume dispatch',
                  ),
                  const SizedBox(height: 20),

                  AppButton(
                    label: isCounter ? 'Submit Counter-Proposal' : 'Submit Proposal to Broker',
                    onPressed: () {
                      final r = double.tryParse(rateController.text.trim());
                      if (r == null || r <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid positive commission rate')),
                        );
                        return;
                      }
                      Navigator.pop(context, true);
                    },
                    variant: ButtonVariant.primary,
                    icon: LucideIcons.send,
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      final rate = double.parse(rateController.text.trim());
      setState(() => _isLoading = true);
      try {
        if (isCounter) {
          await _repository.respondToCommission(
            requestId: widget.requestId,
            brokerId: widget.brokerId,
            actionType: 'COUNTER',
            counterRate: rate,
            counterBasis: selectedBasis,
            notes: notesController.text.trim(),
          );
        } else {
          await _repository.proposeCommission(
            requestId: widget.requestId,
            brokerId: widget.brokerId,
            rate: rate,
            basis: selectedBasis,
            notes: notesController.text.trim(),
          );
        }
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commission proposal of ₹$rate ($selectedBasis) submitted to Mandi Broker.'),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Proposal error: $e'), backgroundColor: AppColors.error),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAcceptProposal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final prop = _commissionSummary?.latestProposal;
        return AlertDialog(
          title: const Text('Confirm Agreed Commission Terms'),
          content: Text(
            'Do you accept the broker commission terms of ₹${prop?.commissionRate?.toStringAsFixed(0)} (${prop?.commissionBasis})? Once confirmed, this creates an immutable commercial record.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accept Terms', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await _repository.respondToCommission(
          requestId: widget.requestId,
          brokerId: widget.brokerId,
          actionType: 'ACCEPT',
          notes: 'Seller accepted broker commission proposal.',
        );
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commission terms successfully accepted and confirmed!'),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e'), backgroundColor: AppColors.error),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBrokerName = widget.brokerName ?? 'Bikaner Mandi Broker Desk';
    final effectivePhone = widget.brokerPhone ?? '+919829012345';
    final effectiveLocation = widget.brokerLocation ?? 'Krishi Upaj Mandi Yard';
    final trust = widget.trustScore ?? 98;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(effectiveBrokerName, style: AppTypography.titleMedium),
            Text(
              '$effectiveLocation • Trust $trust%',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.phone, size: 20),
            tooltip: 'Call Broker',
            onPressed: () => _contactLauncher.launchPhone(effectivePhone),
          ),
          IconButton(
            icon: const Icon(LucideIcons.messageCircle, size: 20),
            tooltip: 'Broker WhatsApp',
            onPressed: () => _contactLauncher.launchWhatsApp(effectivePhone),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(LucideIcons.messageSquare, size: 16), text: 'Broker Chat'),
            Tab(icon: Icon(LucideIcons.scale, size: 16), text: 'Commission Terms'),
          ],
        ),
      ),
      body: _isLoading
          ? const AppLoadingIndicator(message: 'Loading Mandi Broker communication desk...')
          : Column(
              children: [
                // Commodity Context & Privacy Shield Bar
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.commodityContext != null
                              ? '${widget.commodityContext} • Counterparty Shield Active (Broker-mediated)'
                              : 'Commodity Mandate • Counterparty Shield Active (Broker-mediated)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: Chat Stream
                      _buildChatTab(),

                      // TAB 2: Commission Negotiation
                      _buildNegotiationTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ============================================================================
  // TAB 1: CHAT INTERFACE
  // ============================================================================

  Widget _buildChatTab() {
    final timeFormat = DateFormat('hh:mm a');

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    'No messages yet. Send a message to initiate discussion with your Mandi Broker.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];

                    if (msg.isSystemEvent) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                          ),
                        ),
                      );
                    }

                    return Align(
                      alignment: msg.isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: msg.isMine ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: Radius.circular(msg.isMine ? 12 : 2),
                            bottomRight: Radius.circular(msg.isMine ? 2 : 12),
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: msg.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.senderName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: msg.isMine ? Colors.white70 : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg.text,
                              style: TextStyle(
                                fontSize: 13,
                                color: msg.isMine ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeFormat.format(msg.timestamp),
                              style: TextStyle(
                                fontSize: 9,
                                color: msg.isMine ? Colors.white60 : AppColors.textMutedLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Chat Input Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message to broker...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.borderLight)),
                      filled: true,
                      fillColor: AppColors.backgroundLight,
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _handleSendMessage,
                  icon: _isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.send, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // TAB 2: COMMISSION NEGOTIATION
  // ============================================================================

  Widget _buildNegotiationTab() {
    final summary = _commissionSummary;
    final isAgreed = summary?.isAgreed == true;
    final hasActiveProposal = summary?.hasActiveProposal == true;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isAgreed ? AppColors.successContainer : (hasActiveProposal ? Colors.amber.shade50 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAgreed ? AppColors.success : (hasActiveProposal ? Colors.amber.shade400 : AppColors.borderLight),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isAgreed ? LucideIcons.checkCircle2 : (hasActiveProposal ? LucideIcons.scale : LucideIcons.helpCircle),
                size: 28,
                color: isAgreed ? AppColors.success : (hasActiveProposal ? Colors.amber.shade800 : AppColors.textSecondaryLight),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAgreed ? 'Commission Agreed & Confirmed' : (hasActiveProposal ? 'Negotiation in Progress' : 'No Commission Agreement Yet'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isAgreed ? AppColors.success : (hasActiveProposal ? Colors.amber.shade900 : AppColors.textPrimaryLight),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAgreed
                          ? 'Agreed Rate: ₹${summary!.agreedRate!.toStringAsFixed(0)} (${summary.agreedBasis})'
                          : (hasActiveProposal ? 'Active terms proposal awaiting party acceptance' : 'Propose commission terms below to align broker mandate.'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Active Proposal Card (if negotiating)
        if (hasActiveProposal && summary?.latestProposal != null) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Current Active Proposal', style: AppTypography.titleMedium),
                    StatusBadge(status: summary!.latestProposal!.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '₹${summary.latestProposal!.commissionRate?.toStringAsFixed(0)} ${summary.latestProposal!.commissionBasis}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Proposed by: ${summary.latestProposal!.senderName} (${summary.latestProposal!.senderRole.toUpperCase()})',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
                if (summary.latestProposal!.notes != null && summary.latestProposal!.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Notes: "${summary.latestProposal!.notes}"',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 16),

                // Action buttons: If proposed by broker, seller can accept or counter
                if (summary.canSellerAccept) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _handleAcceptProposal,
                          icon: const Icon(LucideIcons.check, size: 16),
                          label: const Text('Accept Terms'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openProposeCommissionDialog(isCounter: true),
                          icon: const Icon(LucideIcons.rotateCcw, size: 16),
                          label: const Text('Counter'),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6)),
                    child: const Text(
                      'Your proposal is pending Mandi Broker review. You will receive an alert once accepted or countered.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Propose New Terms Button
        if (!isAgreed) ...[
          AppButton(
            label: hasActiveProposal ? 'Submit Revised Proposal' : 'Propose Commission Rate',
            onPressed: () => _openProposeCommissionDialog(isCounter: false),
            variant: ButtonVariant.primary,
            icon: LucideIcons.plus,
          ),
          const SizedBox(height: 24),
        ],

        // Negotiation History Timeline
        Text('Negotiation History & Audit Trail', style: AppTypography.titleMedium),
        const SizedBox(height: 10),

        if (summary?.history.isEmpty ?? true)
          const Text('No prior negotiation events.', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight))
        else
          ...summary!.history.map((event) => _buildTimelineItem(event, dateFormat)),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTimelineItem(NegotiationEvent event, DateFormat dateFormat) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: event.actionType == NegotiationActionType.accept ||
                      event.actionType == NegotiationActionType.commissionAccept
                  ? AppColors.successContainer
                  : AppColors.primaryContainer,
              child: Icon(
                event.actionType == NegotiationActionType.accept ||
                        event.actionType == NegotiationActionType.commissionAccept
                    ? LucideIcons.check
                    : LucideIcons.scale,
                size: 14,
                color: event.actionType == NegotiationActionType.accept ||
                        event.actionType == NegotiationActionType.commissionAccept
                    ? AppColors.success
                    : AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${event.actionType.value} • ${event.senderName}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        dateFormat.format(event.createdAt),
                        style: const TextStyle(fontSize: 10, color: AppColors.textMutedLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (event.commissionRate != null)
                    Text(
                      'Rate: ₹${event.commissionRate?.toStringAsFixed(0)} (${event.commissionBasis})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  if (event.notes != null && event.notes!.isNotEmpty)
                    Text(
                      event.notes!,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
