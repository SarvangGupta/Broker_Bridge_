import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Single chronological negotiation or proposal round between Broker and Buyer.
@immutable
class NegotiationRoundItem {
  final String id;
  final int versionNumber;
  final String status;
  final String actorRole; // 'broker' | 'buyer'
  final String actorName;
  final double rate; // Landed offered price
  final double quantity;
  final String? deliveryDate;
  final String? paymentTerms;
  final String? packaging;
  final String? notes;
  final DateTime createdAt;
  final bool isCurrent;

  const NegotiationRoundItem({
    required this.id,
    required this.versionNumber,
    required this.status,
    required this.actorRole,
    required this.actorName,
    required this.rate,
    required this.quantity,
    this.deliveryDate,
    this.paymentTerms,
    this.packaging,
    this.notes,
    required this.createdAt,
    this.isCurrent = false,
  });

  bool get isBroker => actorRole.toLowerCase() != 'buyer';
  int get roundNumber => versionNumber;
  String get senderRole => actorRole;
  String get senderName => actorName;
  double get proposedPrice => rate;
  double get proposedQuantity => quantity;
  String get createdAtFormatted {
    final now = DateTime.now();
    if (createdAt.year == now.year && createdAt.month == now.month && createdAt.day == now.day) {
      return DateFormat('hh:mm a').format(createdAt);
    }
    return DateFormat('dd MMM, hh:mm a').format(createdAt);
  }

  factory NegotiationRoundItem.fromJson(Map<String, dynamic> json, {bool isCurrent = false}) {
    final payload = (json['payload'] as Map<String, dynamic>?) ??
        (json['snapshotPayload'] as Map<String, dynamic>?) ??
        {};

    final role = (payload['originatorRole']?.toString() ??
            json['actorRole']?.toString() ??
            'broker')
        .toLowerCase();

    final rateVal = (payload['landedPrice'] as num?)?.toDouble() ??
        (payload['rate'] as num?)?.toDouble() ??
        (payload['price'] as num?)?.toDouble() ??
        (json['proposedPrice'] as num?)?.toDouble() ??
        0.0;

    final qtyVal = (payload['quantity'] as num?)?.toDouble() ??
        (json['proposedQuantity'] as num?)?.toDouble() ??
        0.0;

    final createdAtRaw = json['createdAt'] ?? json['created_at'];
    final parsedDate = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw.toString()) ?? DateTime.now()
        : DateTime.now();

    final rawVer = json['versionNumber'] ?? json['version_number'] ?? payload['versionNumber'];
    final ver = (rawVer as num?)?.toInt() ?? 1;

    return NegotiationRoundItem(
      id: json['id']?.toString() ?? 'round_$ver',
      versionNumber: ver,
      status: json['status']?.toString() ?? payload['status']?.toString() ?? 'Proposed to Buyer',
      actorRole: role,
      actorName: role == 'buyer' ? 'Buyer Counter-Offer' : 'Broker Desk Proposal',
      rate: rateVal,
      quantity: qtyVal,
      deliveryDate: payload['deliveryDate']?.toString() ?? json['deliveryDate']?.toString(),
      paymentTerms: payload['paymentTerms']?.toString() ?? json['paymentTerms']?.toString(),
      packaging: payload['packaging']?.toString() ?? payload['packagingType']?.toString() ?? json['packaging']?.toString(),
      notes: payload['brokerNotes']?.toString() ?? payload['remarks']?.toString() ?? payload['notes']?.toString() ?? json['notes']?.toString(),
      createdAt: parsedDate,
      isCurrent: isCurrent,
    );
  }
}

/// Active negotiation state and commercial terms for a buyer requirement.
@immutable
class RequirementNegotiationData {
  final String requirementId;
  final String? requestId;
  final int currentVersionNumber;
  final String currentStatus;
  final double offeredPrice;
  final double proposedQuantity;
  final String unitSymbol;
  final String deliveryTerms;
  final String? deliveryDate;
  final String paymentTerms;
  final String packagingType;
  final String? brokerNotes;
  final List<NegotiationRoundItem> rounds;

  const RequirementNegotiationData({
    required this.requirementId,
    this.requestId,
    required this.currentVersionNumber,
    required this.currentStatus,
    required this.offeredPrice,
    required this.proposedQuantity,
    this.unitSymbol = 'MT',
    this.deliveryTerms = 'FOR Destination',
    this.deliveryDate,
    this.paymentTerms = 'Standard Escrow Settlement via Broker Desk',
    this.packagingType = '50kg HDPE / PP Bags',
    this.brokerNotes,
    this.rounds = const [],
  });

  factory RequirementNegotiationData.fromJson(Map<String, dynamic> json) {
    final details = (json['details'] as Map<String, dynamic>?) ?? json;
    final timelineRaw = (json['timeline'] as List<dynamic>?) ??
        (details['rounds'] as List<dynamic>?) ??
        [];

    final parsedRounds = <NegotiationRoundItem>[];
    for (int i = 0; i < timelineRaw.length; i++) {
      final item = timelineRaw[i];
      if (item is Map<String, dynamic>) {
        final isLast = i == timelineRaw.length - 1;
        parsedRounds.add(NegotiationRoundItem.fromJson(item, isCurrent: isLast));
      }
    }

    return RequirementNegotiationData(
      requirementId: details['requirementId']?.toString() ?? '',
      requestId: details['requestId']?.toString(),
      currentVersionNumber: (details['currentVersionNumber'] as num?)?.toInt() ??
          (parsedRounds.isNotEmpty ? parsedRounds.last.versionNumber : 1),
      currentStatus: details['currentStatus']?.toString() ?? 'Open',
      offeredPrice: (details['offeredPrice'] as num?)?.toDouble() ??
          (details['targetPrice'] as num?)?.toDouble() ??
          0.0,
      proposedQuantity: (details['proposedQuantity'] as num?)?.toDouble() ??
          (details['targetQuantity'] as num?)?.toDouble() ??
          0.0,
      unitSymbol: details['unitSymbol']?.toString() ?? 'MT',
      deliveryTerms: details['deliveryTerms']?.toString() ?? 'FOR Destination',
      deliveryDate: details['deliveryDate']?.toString(),
      paymentTerms: details['paymentTerms']?.toString() ??
          'Standard Escrow Settlement via Broker Desk',
      packagingType: details['packagingType']?.toString() ??
          '50kg HDPE / PP Bags',
      brokerNotes: details['brokerNotes']?.toString(),
      rounds: parsedRounds,
    );
  }

  NegotiationRoundItem? get activeProposal => rounds.isNotEmpty ? rounds.last : null;
  bool get hasPriorProposals => rounds.isNotEmpty;
}
