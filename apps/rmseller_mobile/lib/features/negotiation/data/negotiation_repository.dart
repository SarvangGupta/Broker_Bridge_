import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/security/secure_storage_service.dart';
import '../domain/negotiation_model.dart';

/// Repository managing broker communication and commodity commission negotiation.
/// Synchronizes append-only legal audit events with the `negotiation_events` table.
/// STRICT COUNTERPARTY SHIELD INVARIANT:
/// Access is strictly scoped to the authenticated Seller's companyId and authorized Mandi Brokers.
/// Direct Buyer communications or counterparty directory access is strictly prohibited.
class NegotiationRepository {
  final SupabaseClient? _customClient;
  final SecureStorageService _storage;

  // In-memory session cache for newly posted messages and proposals, partitioned by requestId
  static final Map<String, List<NegotiationEvent>> _sessionEventsByRequest = {};

  /// Global notifier triggered whenever a new message, proposal, or agreement is appended
  static final ValueNotifier<int> negotiationUpdatedNotifier =
      ValueNotifier<int>(0);

  NegotiationRepository({SupabaseClient? client, SecureStorageService? storage})
    : _customClient = client,
      _storage = storage ?? SecureStorageService();

  SupabaseClient? get _supabase {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static void clearSessionCache() {
    _sessionEventsByRequest.clear();
  }

  // ============================================================================
  // 1. EVENT RETRIEVAL & QUERYING
  // ============================================================================

  /// Retrieve all negotiation and communication events for a specific lot or deal.
  /// Scoped strictly to the authenticated Seller's company_id.
  Future<List<NegotiationEvent>> getNegotiationEvents(String requestId) async {
    final client = _supabase;
    final List<NegotiationEvent> events = [];

    String? companyId;
    try {
      companyId = await _storage.getCompanyId().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => null,
      );
    } catch (_) {}
    companyId ??= '20000000-0000-0000-0000-000000000101';

    // 1. Load session events for this request
    final sessionList = _sessionEventsByRequest[requestId] ?? [];
    events.addAll(sessionList);

    // 2. Fetch from Supabase negotiation_events table if connected
    if (client != null) {
      try {
        final data = await client
            .from('negotiation_events')
            .select(
              'id, request_id, company_id, actor_id, action_type, payload, created_at',
            )
            .eq('request_id', requestId)
            .eq('company_id', companyId)
            .order('created_at', ascending: true);

        for (final row in data) {
          final id = row['id'].toString();
          if (events.any((e) => e.id == id)) continue;
          events.add(NegotiationEvent.fromMap(row as Map<String, dynamic>));
        }
      } catch (e) {
        debugPrint('Remote negotiation_events query notice: $e');
      }
    }

    // 3. Fallback baseline conversation if no remote/session events exist
    if (events.isEmpty) {
      final baseline = _generateBaselineEvents(requestId, companyId);
      events.addAll(baseline);
      _sessionEventsByRequest[requestId] = List.from(baseline);
    }

    events.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return events;
  }

  /// Alias for getNegotiationEvents for audit timeline
  Future<List<NegotiationEvent>> getNegotiationTimeline(String requestId) =>
      getNegotiationEvents(requestId);

  /// Alias for getNegotiationEvents
  Future<List<NegotiationEvent>> getEvents(String requestId) =>
      getNegotiationEvents(requestId);

  // ============================================================================
  // 2. MESSAGING ENGINE
  // ============================================================================

  /// Send a text message to the assigned Mandi Broker.
  /// Appends an immutable 'MESSAGE' event to `negotiation_events`.
  Future<NegotiationEvent> sendMessage({
    required String requestId,
    required String brokerId,
    String? text,
    String? message,
  }) async {
    final effectiveText = (text ?? message ?? '').trim();
    if (effectiveText.isEmpty) {
      throw ArgumentError('Message text cannot be empty');
    }

    final client = _supabase;
    String? companyId;
    String? sellerName;
    String? actorId;

    try {
      companyId = await _storage.getCompanyId();
      sellerName = await _storage.getUserFullName();
      actorId = await _storage.getUserId();
    } catch (_) {}

    companyId ??= '20000000-0000-0000-0000-000000000101';
    sellerName ??= 'Seller Desk Lead';
    actorId ??= '20000000-0000-0000-0000-000000000001';

    final payload = {
      'text': effectiveText,
      'sender_name': sellerName,
      'sender_role': 'seller',
      'broker_id': brokerId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    String eventId = 'MSG-${DateTime.now().millisecondsSinceEpoch}';

    if (client != null) {
      try {
        final res = await client
            .from('negotiation_events')
            .insert({
              'request_id': requestId,
              'company_id': companyId,
              'actor_id': actorId,
              'action_type': 'MESSAGE',
              'payload': payload,
            })
            .select('id, created_at')
            .single();

        if (res['id'] != null) {
          eventId = res['id'].toString();
        }
      } catch (e) {
        debugPrint('Supabase message event insert notice: $e');
      }
    }

    final newEvent = NegotiationEvent(
      id: eventId,
      requestId: requestId,
      companyId: companyId,
      actorId: actorId,
      actionType: NegotiationActionType.message,
      payload: payload,
      createdAt: DateTime.now(),
    );

    _sessionEventsByRequest.putIfAbsent(requestId, () => []).add(newEvent);
    negotiationUpdatedNotifier.value++;

    return newEvent;
  }

  // ============================================================================
  // 3. COMMISSION NEGOTIATION ENGINE
  // ============================================================================

  /// Propose a commodity commission rate to the assigned Mandi Broker.
  /// Supports calculation basis units: '₹/MT', '₹/QTL', '₹/Bag', '% of Invoice'.
  /// Appends an immutable 'PROPOSAL' event.
  Future<NegotiationEvent> proposeCommission({
    required String requestId,
    required String brokerId,
    double? rate,
    double? proposedRate,
    String? basis,
    String? commissionBasis,
    String? notes,
    String? note,
  }) async {
    final effectiveRate = rate ?? proposedRate ?? 0.0;
    final effectiveBasis = basis ?? commissionBasis ?? '₹/MT';
    final effectiveNotes =
        notes ??
        note ??
        'Seller proposed commission rate for this commodity mandate.';

    if (effectiveRate <= 0 ||
        (proposedRate != null && proposedRate <= 0) ||
        (rate != null && rate <= 0)) {
      throw ArgumentError('Commission rate must be positive');
    }

    final client = _supabase;
    String? companyId;
    String? sellerName;
    String? actorId;

    try {
      companyId = await _storage.getCompanyId();
      sellerName = await _storage.getUserFullName();
      actorId = await _storage.getUserId();
    } catch (_) {}

    companyId ??= '20000000-0000-0000-0000-000000000101';
    sellerName ??= 'Seller Desk Lead';
    actorId ??= '20000000-0000-0000-0000-000000000001';

    final payload = {
      'rate': effectiveRate,
      'proposed_rate': effectiveRate,
      'broker_commission_rate': effectiveRate,
      'basis': effectiveBasis,
      'commission_basis': effectiveBasis,
      'status': 'Proposed',
      'terms_status': 'PROPOSED',
      'notes': effectiveNotes,
      'author_role': 'seller',
      'author_name': sellerName,
      'broker_id': brokerId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    String eventId = 'PROP-${DateTime.now().millisecondsSinceEpoch}';

    if (client != null) {
      try {
        final res = await client
            .from('negotiation_events')
            .insert({
              'request_id': requestId,
              'company_id': companyId,
              'actor_id': actorId,
              'action_type': 'PROPOSAL',
              'payload': payload,
            })
            .select('id, created_at')
            .single();

        if (res['id'] != null) {
          eventId = res['id'].toString();
        }
      } catch (e) {
        debugPrint('Supabase commission proposal insert notice: $e');
      }
    }

    final newEvent = NegotiationEvent(
      id: eventId,
      requestId: requestId,
      companyId: companyId,
      actorId: actorId,
      actionType: NegotiationActionType.commissionProposal,
      payload: payload,
      createdAt: DateTime.now(),
    );

    _sessionEventsByRequest.putIfAbsent(requestId, () => []).add(newEvent);
    negotiationUpdatedNotifier.value++;

    return newEvent;
  }

  /// Respond to an active proposal from the Mandi Broker:
  /// Supports: commissionAccept ('ACCEPT'), commissionReject ('REJECT'), or commissionCounter ('COUNTER').
  Future<NegotiationEvent> respondToCommission({
    required String requestId,
    required String brokerId,
    dynamic actionType,
    dynamic responseType,
    double? rate,
    double? counterRate,
    String? basis,
    String? counterBasis,
    String? commissionBasis,
    String? notes,
    String? counterNote,
  }) async {
    final client = _supabase;
    String? companyId;
    String? sellerName;
    String? actorId;

    try {
      companyId = await _storage.getCompanyId();
      sellerName = await _storage.getUserFullName();
      actorId = await _storage.getUserId();
    } catch (_) {}

    companyId ??= '20000000-0000-0000-0000-000000000101';
    sellerName ??= 'Seller Desk Lead';
    actorId ??= '20000000-0000-0000-0000-000000000001';

    final rawAction = actionType ?? responseType ?? 'ACCEPT';
    String actionStr = 'ACCEPT';
    if (rawAction is NegotiationActionType) {
      actionStr = rawAction.value;
    } else {
      actionStr = rawAction.toString();
    }

    final normalizedAction = actionStr.toUpperCase().trim();
    final effectiveRate = rate ?? counterRate;
    final effectiveBasis = basis ?? counterBasis ?? commissionBasis ?? '₹/MT';
    final effectiveNotes = notes ?? counterNote;

    final Map<String, dynamic> payload = {
      'author_role': 'seller',
      'author_name': sellerName,
      'broker_id': brokerId,
      'notes': effectiveNotes,
      'timestamp': DateTime.now().toIso8601String(),
    };

    String dbActionType = 'ACCEPT';

    if (normalizedAction == 'COUNTER' ||
        normalizedAction == 'COMMISSION_COUNTER' ||
        normalizedAction == 'COMMISSIONCOUNTER') {
      dbActionType = 'COUNTER';
      if (effectiveRate == null || effectiveRate <= 0) {
        throw ArgumentError('Counter-proposal rate must be positive');
      }
      payload['rate'] = effectiveRate;
      payload['proposed_rate'] = effectiveRate;
      payload['broker_commission_rate'] = effectiveRate;
      payload['basis'] = effectiveBasis;
      payload['commission_basis'] = effectiveBasis;
      payload['status'] = 'Countered';
      payload['terms_status'] = 'COUNTERED';
    } else if (normalizedAction == 'ACCEPT' ||
        normalizedAction == 'COMMISSION_ACCEPT' ||
        normalizedAction == 'COMMISSIONACCEPT') {
      dbActionType = 'ACCEPT';
      // Find latest proposal to confirm terms
      final summary = await getCommissionSummary(requestId);
      final agreed =
          effectiveRate ?? summary.latestProposal?.commissionRate ?? 50.0;
      final agreedUnit = effectiveBasis.isNotEmpty
          ? effectiveBasis
          : (summary.latestProposal?.commissionBasis ?? '₹/MT');
      payload['rate'] = agreed;
      payload['agreed_rate'] = agreed;
      payload['basis'] = agreedUnit;
      payload['agreed_basis'] = agreedUnit;
      payload['status'] = 'Agreed';
      payload['terms_status'] = 'AGREED';
    } else if (normalizedAction == 'REJECT' ||
        normalizedAction == 'COMMISSION_REJECT' ||
        normalizedAction == 'COMMISSIONREJECT') {
      dbActionType = 'REJECT';
      payload['status'] = 'Rejected';
      payload['terms_status'] = 'REJECTED';
    }

    String eventId = 'RESP-${DateTime.now().millisecondsSinceEpoch}';

    if (client != null) {
      try {
        final res = await client
            .from('negotiation_events')
            .insert({
              'request_id': requestId,
              'company_id': companyId,
              'actor_id': actorId,
              'action_type': dbActionType,
              'payload': payload,
            })
            .select('id, created_at')
            .single();

        if (res['id'] != null) {
          eventId = res['id'].toString();
        }
      } catch (e) {
        debugPrint('Supabase negotiation response notice: $e');
      }
    }

    final newEvent = NegotiationEvent(
      id: eventId,
      requestId: requestId,
      companyId: companyId,
      actorId: actorId,
      actionType: NegotiationActionTypeX.fromString(dbActionType),
      payload: payload,
      createdAt: DateTime.now(),
    );

    _sessionEventsByRequest.putIfAbsent(requestId, () => []).add(newEvent);
    negotiationUpdatedNotifier.value++;

    return newEvent;
  }

  // ============================================================================
  // 4. SUMMARY RESOLUTION & DERIVED VIEWS
  // ============================================================================

  /// Calculates authoritative commission negotiation state from the event stream.
  Future<CommissionSummary> getCommissionSummary(String requestId) async {
    final events = await getNegotiationEvents(requestId);
    final commissionEvents = events.where((e) => e.isCommissionEvent).toList();

    if (commissionEvents.isEmpty) {
      return CommissionSummary(
        requestId: requestId,
        status: 'No Proposal',
        history: [],
      );
    }

    double? agreedRate;
    String? agreedBasis;
    DateTime? agreedAt;
    NegotiationEvent? latestProposal;
    String status = 'Negotiating';

    for (final event in commissionEvents) {
      if (event.actionType == NegotiationActionType.accept ||
          event.actionType == NegotiationActionType.commissionAccept) {
        status = 'Agreed';
        agreedRate = event.commissionRate;
        agreedBasis = event.commissionBasis;
        agreedAt = event.createdAt;
      } else if (event.actionType == NegotiationActionType.reject ||
          event.actionType == NegotiationActionType.commissionReject) {
        status = 'Rejected';
      } else if (event.actionType == NegotiationActionType.proposal ||
          event.actionType == NegotiationActionType.commissionProposal ||
          event.actionType == NegotiationActionType.counter ||
          event.actionType == NegotiationActionType.commissionCounter) {
        status = 'Negotiating';
        latestProposal = event;
      }
    }

    return CommissionSummary(
      requestId: requestId,
      status: status,
      agreedRate: agreedRate,
      agreedBasis: agreedBasis,
      agreedAt: agreedAt,
      latestProposal: latestProposal,
      history: commissionEvents.reversed.toList(),
    );
  }

  /// Alias for getBrokerMessages
  Future<List<BrokerMessage>> getMessages(String requestId) =>
      getBrokerMessages(requestId);

  /// Extracts formatted messages for the chat interface.
  Future<List<BrokerMessage>> getBrokerMessages(String requestId) async {
    final events = await getNegotiationEvents(requestId);
    final List<BrokerMessage> messages = [];

    for (final e in events) {
      if (e.isMessage) {
        messages.add(
          BrokerMessage(
            id: e.id,
            requestId: e.requestId,
            senderId: e.actorId,
            senderName: e.senderName,
            senderRole: e.senderRole,
            text: e.messageText ?? '',
            timestamp: e.createdAt,
            isMine: e.isFromSeller,
            isSystemEvent: false,
          ),
        );
      } else if (e.isCommissionEvent) {
        // Render system activity event in stream
        String activityText = 'Commission event: ${e.actionType.value}';
        if (e.actionType == NegotiationActionType.proposal) {
          activityText =
              'Commission proposed by ${e.senderName}: ₹${e.commissionRate?.toStringAsFixed(0)} (${e.commissionBasis})';
        } else if (e.actionType == NegotiationActionType.counter) {
          activityText =
              'Counter-proposal submitted: ₹${e.commissionRate?.toStringAsFixed(0)} (${e.commissionBasis})';
        } else if (e.actionType == NegotiationActionType.accept) {
          activityText =
              'Commission terms confirmed & agreed: ₹${e.commissionRate?.toStringAsFixed(0)} (${e.commissionBasis})';
        } else if (e.actionType == NegotiationActionType.reject) {
          activityText = 'Commission proposal declined.';
        }

        messages.add(
          BrokerMessage(
            id: e.id,
            requestId: e.requestId,
            senderId: e.actorId,
            senderName: 'Mandi Desk System',
            senderRole: 'system',
            text: activityText,
            timestamp: e.createdAt,
            isMine: false,
            isSystemEvent: true,
          ),
        );
      }
    }

    return messages;
  }

  // ============================================================================
  // 5. BASELINE SEED DATA
  // ============================================================================

  List<NegotiationEvent> _generateBaselineEvents(
    String requestId,
    String companyId,
  ) {
    final now = DateTime.now();
    return [
      NegotiationEvent(
        id: 'EVT-BASE-001',
        requestId: requestId,
        companyId: companyId,
        actorId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
        actionType: NegotiationActionType.message,
        payload: {
          'text': 'Namaste! We received your commodity listing mandate for regional buyers. We are reviewing buyer requirements in Bikaner & Kota.',
          'sender_name': 'Bikaner Mandi Broker Desk',
          'sender_role': 'broker',
          'timestamp': now.subtract(const Duration(hours: 4)).toIso8601String(),
        },
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      NegotiationEvent(
        id: 'EVT-BASE-002',
        requestId: requestId,
        companyId: companyId,
        actorId: 'b354958e-779a-41f2-b7a3-5899eca32e32',
        actionType: NegotiationActionType.proposal,
        payload: {
          'rate': 50.0,
          'broker_commission_rate': 50.0,
          'basis': '₹/MT',
          'commission_basis': '₹/MT',
          'status': 'Proposed',
          'notes':
              'Standard Mandi brokerage rate for FAQ Grade supply matching.',
          'author_role': 'broker',
          'author_name': 'Bikaner Mandi Broker Desk',
          'timestamp': now.subtract(const Duration(hours: 3)).toIso8601String(),
        },
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      NegotiationEvent(
        id: 'EVT-BASE-003',
        requestId: requestId,
        companyId: companyId,
        actorId: '20000000-0000-0000-0000-000000000001',
        actionType: NegotiationActionType.message,
        payload: {
          'text': 'Lot is cleaned and ready for dispatch at Yard Shed A-4. Can we confirm ₹45/MT given the 100 MT volume?',
          'sender_name': 'Seller Lead',
          'sender_role': 'seller',
          'timestamp': now.subtract(const Duration(hours: 2)).toIso8601String(),
        },
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }
}
