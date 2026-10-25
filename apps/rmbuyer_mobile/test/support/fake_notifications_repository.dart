import 'dart:async';

import 'package:rmbuyer_mobile/features/notifications/data/buyer_notifications_repository.dart';
import 'package:rmbuyer_mobile/features/notifications/domain/buyer_notification_model.dart';

const reqId = '11111111-1111-4111-8111-111111111111';
const otherReqId = '22222222-2222-4222-8222-222222222222';
const dealId = '33333333-3333-4333-8333-333333333333';
const quoteId = '44444444-4444-4444-8444-444444444444';

/// Rows shaped exactly like the production writers produce them
/// (src/server/actions/broker-*.ts), for test use only.
List<Map<String, dynamic>> sampleRows() => [
  {
    'id': 'n-confirm',
    'title': 'Contract Signature Required: Maize',
    'message':
        'Broker has dispatched Contract Version 2 for digital signature.',
    'event_type': 'FINAL_CONFIRMATION_REQUIRED',
    'is_read': false,
    'created_at': '2026-10-25T08:30:00Z',
    'action_url': '/buyer/confirmations?requestId=$quoteId',
  },
  {
    'id': 'n-deal',
    'title': 'New Deal Draft Created: Maize',
    'message': 'Broker created Deal Draft for 20 MT.',
    'event_type': 'DEAL_VERSION_UPDATE',
    'is_read': false,
    'created_at': '2026-10-24T10:00:00Z',
    'action_url': '/broker/deals/$dealId',
  },
  {
    'id': 'n-req',
    'title': 'Commercial Proposal: Maize',
    'message': 'Proposal for your requirement.',
    'event_type': 'DEAL_VERSION_UPDATE',
    'is_read': true,
    'read_at': '2026-10-24T11:00:00Z',
    'created_at': '2026-10-23T10:00:00Z',
    'action_url': '/buyer/requirements',
    'payload': {'requirementId': reqId},
  },
];

class FakeNotificationsRepository extends BuyerNotificationsRepository {
  List<BuyerNotification> rows;
  Object? loadError;
  Object? markError;
  Completer<void>? markGate;
  Set<String> ownRequirements;
  int loads = 0;
  final List<String> marked = [];
  int markAllCalls = 0;

  FakeNotificationsRepository({
    List<Map<String, dynamic>>? rows,
    this.ownRequirements = const {reqId},
  }) : rows = BuyerNotificationsRepository.dedupe([
         for (final r in rows ?? sampleRows()) BuyerNotification.fromMap(r),
       ]);

  @override
  Future<List<BuyerNotification>> getNotifications() async {
    loads++;
    if (loadError != null) throw loadError!;
    return List.of(rows);
  }

  @override
  Future<void> markAsRead(String id) async {
    marked.add(id);
    if (markGate != null) await markGate!.future;
    if (markError != null) throw markError!;
    rows = [for (final n in rows) n.id == id ? n.asRead() : n];
  }

  @override
  Future<Set<String>> markAllAsRead() async {
    markAllCalls++;
    if (markError != null) throw markError!;
    final ids = {
      for (final n in rows)
        if (!n.isRead) n.id,
    };
    rows = [for (final n in rows) n.asRead()];
    return ids;
  }

  @override
  Future<bool> isOwnRequirement(String requirementId) async =>
      ownRequirements.contains(requirementId);
}
