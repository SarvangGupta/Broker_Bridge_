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
  State<BrokerCommunicationScreen> createState() =>
      _BrokerCommunicationScreenState();
}

class _BrokerCommunicationScreenState extends State<BrokerCommunicationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NegotiationRepository _repository = NegotiationRepository();
  final ContactLauncherService _contactLauncher =
      const ContactLauncherService();

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
    NegotiationRepository.negotiationUpdatedNotifier.addListener(
      _onDataUpdated,
    );
  }

  @override
  void dispose() {
    NegotiationRepository.negotiationUpdatedNotifier.removeListener(
      _onDataUpdated,
    );
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
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _openProposeCommissionDialog({bool isCounter = false}) async {
    final rateController = TextEditingController();
    final notesController = TextEditingController();
    String selectedBasis = '₹/MT';

    if (isCounter &&
        _commissionSummary?.latestProposal?.commissionRate != null) {
      rateController.text = _commissionSummary!.latestProposal!.commissionRate!
          .toStringAsFixed(0);
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
                        isCounter
                            ? 'Counter Commission Proposal'
                            : 'Propose Commission Rate',
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
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
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Commission Calculation Basis *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedBasis,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: '₹/MT',
                                  child: Text(
                                    '₹/MT (Per Metric Ton)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: '₹/QTL',
                                  child: Text(
                                    '₹/QTL (Per Quintal)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: '₹/Bag',
                                  child: Text(
                                    '₹/Bag (Per 50kg Bag)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: '% of Invoice',
                                  child: Text(
                                    '% of Invoice',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null)
                                  setSheetState(() => selectedBasis = val);
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
                    label: isCounter
                        ? 'Submit Counter-Proposal'
                        : 'Submit Proposal to Broker',
                    onPressed: () {
                      final r = double.tryParse(rateController.text.trim());
                      if (r == null || r <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter a valid positive commission rate',
                            ),
                          ),
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
            content: Text(
              'Commission proposal of ₹$rate ($selectedBasis) submitted to Mandi Broker.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proposal error: $e'),
            backgroundColor: AppColors.error,
          ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Accept Terms',
                style: TextStyle(color: Colors.white),
              ),
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
            content: Text(
              'Commission terms successfully accepted and confirmed!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBrokerName =
        widget.brokerName ?? 'Bikaner Mandi Broker Desk';
    final effectivePhone = widget.brokerPhone ?? '+919829012345';
    final effectiveLocation = widget.brokerLocation ?? 'Krishi Upaj Mandi Yard';
    final trust = widget.trustScore ?? 98;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              effectiveBrokerName,
              style: AppTypography.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                const Icon(
                  LucideIcons.shieldCheck,
                  size: 12,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '$effectiveLocation • Trust $trust%',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.phone, size: 20),
            tooltip: 'Call Broker',
            onPressed: () => _contactLauncher.launchPhone(effectivePhone),
          ),
          PopupMenuButton<String>(
            key: const Key('broker_chat_menu'),
            icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'whatsapp') {
                _contactLauncher.launchWhatsApp(effectivePhone);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'whatsapp',
                child: Row(
                  children: [
                    Icon(LucideIcons.messageCircle, size: 18),
                    SizedBox(width: 12),
                    Text('WhatsApp Broker'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondaryLight,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.messageSquare, size: 16),
                        SizedBox(width: 8),
                        Text('Chat'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.scale, size: 16),
                        SizedBox(width: 8),
                        Text('Terms'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const AppLoadingIndicator(
              message: 'Loading Mandi Broker communication desk...',
            )
          : Column(
              children: [
                // Commodity context & counterparty shield
                Container(
                  key: const Key('broker_mediated_bar'),
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.shieldCheck,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.commodityContext != null
                              ? '${widget.commodityContext} • Broker-mediated trading'
                              : 'Broker-mediated trading',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

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
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];

                    // Commission/system events: compact card opening Terms
                    if (msg.isSystemEvent) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _tabController.animateTo(1),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.scale,
                                    size: 22,
                                    color: Colors.amber.shade800,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      msg.text,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimaryLight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    timeFormat.format(msg.timestamp),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMutedLight,
                                    ),
                                  ),
                                  const Icon(
                                    LucideIcons.chevronRight,
                                    size: 18,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final bubble = Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      decoration: BoxDecoration(
                        color: msg.isMine ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(msg.isMine ? 14 : 4),
                          bottomRight: Radius.circular(msg.isMine ? 4 : 14),
                        ),
                        border: msg.isMine
                            ? null
                            : Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  msg.isMine ? 'You' : msg.senderName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: msg.isMine
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                timeFormat.format(msg.timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: msg.isMine
                                      ? Colors.white70
                                      : AppColors.textMutedLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            msg.text,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: msg.isMine
                                  ? Colors.white
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: msg.isMine
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!msg.isMine) ...[
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primaryContainer,
                              child: const Icon(
                                LucideIcons.landmark,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(child: bubble),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Chat input bar — stays pinned above the keyboard / system bar
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.borderLight)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('broker_chat_input'),
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondaryLight,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.borderLight,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.backgroundLight,
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const Key('broker_chat_send'),
                    tooltip: 'Send',
                    onPressed: _isSending ? null : _handleSendMessage,
                    constraints: const BoxConstraints.tightFor(
                      width: 46,
                      height: 46,
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            LucideIcons.send,
                            size: 20,
                            color: Colors.white,
                          ),
                  ),
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
    final canAccept = summary?.canSellerAccept == true;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final historyFormat = DateFormat('dd MMM, hh:mm a');

    final Color tone = isAgreed
        ? AppColors.success
        : (hasActiveProposal
              ? Colors.amber.shade800
              : AppColors.textSecondaryLight);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        // Status
        Container(
          key: const Key('terms_status_card'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isAgreed
                ? AppColors.successContainer
                : (hasActiveProposal
                      ? Colors.amber.shade50
                      : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tone.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(
                isAgreed
                    ? LucideIcons.checkCircle2
                    : (hasActiveProposal
                          ? LucideIcons.hourglass
                          : LucideIcons.helpCircle),
                size: 26,
                color: tone,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAgreed
                          ? 'Commission Agreed'
                          : (hasActiveProposal
                                ? 'Negotiation in Progress'
                                : 'No Commission Agreement Yet'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isAgreed ? AppColors.success : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAgreed
                          ? 'Agreed rate: ₹${summary!.agreedRate!.toStringAsFixed(0)} (${summary.agreedBasis})'
                          : (hasActiveProposal
                                ? (canAccept
                                      ? 'Waiting for your response.'
                                      : 'Waiting for broker response.')
                                : 'Send an offer to start.'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Current Offer + actions
        if (hasActiveProposal && summary?.latestProposal != null)
          _buildCurrentOfferCard(summary!, dateFormat, canAccept)
        else if (!isAgreed)
          SizedBox(
            width: double.infinity,
            child: _sendNewOfferButton(label: 'Send Offer'),
          ),
        const SizedBox(height: 10),

        // Offer History
        AppCard(
          key: const Key('terms_offer_history'),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Offer History', style: AppTypography.titleSmall),
              const SizedBox(height: 8),
              if (summary?.history.isEmpty ?? true)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No offers yet.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                )
              else
                for (var i = 0; i < summary!.history.length; i++)
                  _buildTimelineItem(
                    summary.history[i],
                    historyFormat,
                    isLast: i == summary.history.length - 1,
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentOfferCard(
    CommissionSummary summary,
    DateFormat dateFormat,
    bool canAccept,
  ) {
    final proposal = summary.latestProposal!;
    return AppCard(
      key: const Key('terms_current_offer'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Current Offer', style: AppTypography.titleSmall),
              ),
              StatusBadge(status: proposal.status),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '₹${proposal.commissionRate?.toStringAsFixed(0)} ${_shortBasis(proposal.commissionBasis)}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'By ${proposal.senderName} • ${dateFormat.format(proposal.createdAt)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
            ),
          ),
          if (proposal.notes != null && proposal.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '"${proposal.notes}"',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),
          if (canAccept) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('terms_accept_button'),
                    onPressed: _handleAcceptProposal,
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('terms_counter_button'),
                    onPressed: () =>
                        _openProposeCommissionDialog(isCounter: true),
                    icon: const Icon(LucideIcons.rotateCcw, size: 16),
                    label: const Text('Counter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimaryLight,
                      minimumSize: const Size(0, 44),
                      side: const BorderSide(color: AppColors.borderLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ] else ...[
            const Text(
              'Your offer is with the broker. You will be alerted on a reply.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: _sendNewOfferButton(label: 'Send New Offer'),
          ),
        ],
      ),
    );
  }

  Widget _sendNewOfferButton({required String label}) {
    return ElevatedButton.icon(
      key: const Key('terms_send_offer_button'),
      onPressed: () => _openProposeCommissionDialog(isCounter: false),
      icon: const Icon(LucideIcons.plus, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 46),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// '₹/MT' → '/ MT'; other bases are shown as-is in brackets.
  String _shortBasis(String? basis) {
    if (basis == null || basis.isEmpty) return '';
    if (basis.startsWith('₹/')) return '/ ${basis.substring(2)}';
    return '($basis)';
  }

  Widget _buildTimelineItem(
    NegotiationEvent event,
    DateFormat dateFormat, {
    required bool isLast,
  }) {
    final isAccept =
        event.actionType == NegotiationActionType.accept ||
        event.actionType == NegotiationActionType.commissionAccept;
    final color = isAccept
        ? AppColors.success
        : (event.isFromSeller ? AppColors.primary : Colors.amber.shade800);
    final title = isAccept
        ? '${event.isFromSeller ? 'You' : 'Broker'} accepted'
        : (event.isFromSeller ? 'Your offer' : 'Broker offer');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(
                    isAccept ? LucideIcons.check : LucideIcons.scale,
                    size: 14,
                    color: color,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.borderLight),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            if (event.commissionRate != null)
                              Text(
                                '₹${event.commissionRate!.toStringAsFixed(0)} ${_shortBasis(event.commissionBasis)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: color,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateFormat.format(event.createdAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMutedLight,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    event.senderName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMutedLight,
                    ),
                  ),
                  if (event.notes != null && event.notes!.isNotEmpty)
                    Text(
                      event.notes!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
