/// Action types supported by the negotiation_events append-only engine.
enum NegotiationActionType {
  message,
  proposal,
  counter,
  accept,
  reject,
  // Direct commission action aliases for API & test compatibility
  commissionProposal,
  commissionCounter,
  commissionAccept,
  commissionReject,
}

extension NegotiationActionTypeX on NegotiationActionType {
  String get value {
    switch (this) {
      case NegotiationActionType.message:
        return 'MESSAGE';
      case NegotiationActionType.proposal:
      case NegotiationActionType.commissionProposal:
        return 'PROPOSAL';
      case NegotiationActionType.counter:
      case NegotiationActionType.commissionCounter:
        return 'COUNTER';
      case NegotiationActionType.accept:
      case NegotiationActionType.commissionAccept:
        return 'ACCEPT';
      case NegotiationActionType.reject:
      case NegotiationActionType.commissionReject:
        return 'REJECT';
    }
  }

  static NegotiationActionType fromString(String val) {
    switch (val.toUpperCase().trim()) {
      case 'MESSAGE':
        return NegotiationActionType.message;
      case 'PROPOSAL':
      case 'COMMISSION_PROPOSAL':
      case 'COMMISSIONPROPOSAL':
        return NegotiationActionType.commissionProposal;
      case 'COUNTER':
      case 'COMMISSION_COUNTER':
      case 'COMMISSIONCOUNTER':
        return NegotiationActionType.commissionCounter;
      case 'ACCEPT':
      case 'COMMISSION_ACCEPT':
      case 'COMMISSIONACCEPT':
        return NegotiationActionType.commissionAccept;
      case 'REJECT':
      case 'COMMISSION_REJECT':
      case 'COMMISSIONREJECT':
        return NegotiationActionType.commissionReject;
      default:
        return NegotiationActionType.message;
    }
  }
}

/// Domain model for an immutable negotiation event stored in `negotiation_events`.
class NegotiationEvent {
  final String id;
  final String requestId;
  final String companyId;
  final String actorId;
  final NegotiationActionType actionType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const NegotiationEvent({
    required this.id,
    required this.requestId,
    required this.companyId,
    required this.actorId,
    required this.actionType,
    required this.payload,
    required this.createdAt,
  });

  bool get isMessage => actionType == NegotiationActionType.message;
  bool get isCommissionEvent =>
      actionType == NegotiationActionType.proposal ||
      actionType == NegotiationActionType.counter ||
      actionType == NegotiationActionType.accept ||
      actionType == NegotiationActionType.reject;

  String? get messageText => payload['text'] as String? ?? payload['message'] as String?;
  String get senderName => (payload['sender_name'] as String?) ?? (payload['author_name'] as String?) ?? 'Desk User';
  String get senderRole => ((payload['sender_role'] as String?) ?? (payload['author_role'] as String?) ?? 'seller').toLowerCase();
  bool get isFromSeller => senderRole == 'seller' || senderRole == 'seller_admin';

  double? get commissionRate =>
      (payload['rate'] as num?)?.toDouble() ??
      (payload['broker_commission_rate'] as num?)?.toDouble() ??
      (payload['agreed_rate'] as num?)?.toDouble();

  String get commissionBasis =>
      (payload['basis'] as String?) ??
      (payload['commission_basis'] as String?) ??
      (payload['agreed_basis'] as String?) ??
      '₹/MT';

  String? get notes => payload['notes'] as String? ?? payload['reason'] as String?;
  String get status => (payload['status'] as String?) ?? 'Proposed';

  factory NegotiationEvent.fromMap(Map<String, dynamic> map) {
    return NegotiationEvent(
      id: map['id']?.toString() ?? '',
      requestId: map['request_id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      actorId: map['actor_id']?.toString() ?? '',
      actionType: NegotiationActionTypeX.fromString(map['action_type']?.toString() ?? 'MESSAGE'),
      payload: (map['payload'] as Map<String, dynamic>?) ?? {},
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'request_id': requestId,
      'company_id': companyId,
      'actor_id': actorId,
      'action_type': actionType.value,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Model representing a chat message between the authenticated Seller and Mandi Broker.
class BrokerMessage {
  final String id;
  final String requestId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'seller' or 'broker'
  final String text;
  final DateTime timestamp;
  final bool isMine;
  final bool isSystemEvent;

  const BrokerMessage({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.timestamp,
    required this.isMine,
    this.isSystemEvent = false,
  });
}

/// Model representing the current agreed and proposed commission state for a commodity lot or deal.
class CommissionSummary {
  final String requestId;
  final String? commodityName;
  final String? brokerName;
  final String status; // 'No Proposal', 'Negotiating', 'Agreed', 'Rejected'
  final double? agreedRate;
  final String? agreedBasis;
  final DateTime? agreedAt;
  final NegotiationEvent? latestProposal;
  final List<NegotiationEvent> history;

  const CommissionSummary({
    required this.requestId,
    this.commodityName,
    this.brokerName,
    required this.status,
    this.agreedRate,
    this.agreedBasis,
    this.agreedAt,
    this.latestProposal,
    this.history = const [],
  });

  bool get isAgreed => status == 'Agreed' && agreedRate != null;
  bool get hasAgreedTerms => isAgreed;
  double? get activeProposedRate => latestProposal?.commissionRate;
  DateTime? get effectiveTimestamp => agreedAt;
  String? get commissionBasis => isAgreed ? agreedBasis : latestProposal?.commissionBasis;

  bool get hasActiveProposal =>
      status == 'Negotiating' && latestProposal != null &&
      (latestProposal!.actionType == NegotiationActionType.proposal ||
       latestProposal!.actionType == NegotiationActionType.commissionProposal ||
       latestProposal!.actionType == NegotiationActionType.counter ||
       latestProposal!.actionType == NegotiationActionType.commissionCounter);

  bool get canSellerAccept =>
      hasActiveProposal && !latestProposal!.isFromSeller;

  String get formattedAgreedTerms => isAgreed
      ? '₹${agreedRate!.toStringAsFixed(agreedRate! % 1 == 0 ? 0 : 2)} ($agreedBasis)'
      : 'Terms Pending';
}
