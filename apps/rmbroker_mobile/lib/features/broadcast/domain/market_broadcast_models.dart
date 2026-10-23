import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../work/domain/offer_model.dart';
import '../../directory/domain/directory_contact.dart';

/// Representation of an authoritative price revision for a seller offer.
@immutable
class SellerOfferPriceRevision {
  final String offerId;
  final String lotNumber;
  final String sellerCompanyId;
  final String sellerCompanyName;
  final String commodityId;
  final String commodityName;
  final String gradeId;
  final String gradeName;
  final double askingPrice; // Authoritative latest asking price
  final String unitSymbol; // e.g. MT or Qtl
  final double availableQuantity;
  final String location; // e.g. Jaipur, Rajasthan
  final int version; // Monotonically increasing revision counter
  final DateTime priceUpdatedAt; // Server-authoritative timestamp
  final bool isEligible;

  const SellerOfferPriceRevision({
    required this.offerId,
    required this.lotNumber,
    required this.sellerCompanyId,
    required this.sellerCompanyName,
    required this.commodityId,
    required this.commodityName,
    required this.gradeId,
    required this.gradeName,
    required this.askingPrice,
    required this.unitSymbol,
    required this.availableQuantity,
    required this.location,
    required this.version,
    required this.priceUpdatedAt,
    this.isEligible = true,
  });

  /// Factory creating an authoritative revision snapshot from OfferItem.
  /// Strictly excludes any confidentialMinimumPrice!
  factory SellerOfferPriceRevision.fromOfferItem(OfferItem item) {
    String loc = '';
    if (item.districtName.isNotEmpty && item.stateName.isNotEmpty) {
      loc = '${item.districtName}, ${item.stateName}';
    } else {
      loc = item.districtName.isNotEmpty ? item.districtName : item.stateName;
    }
    if (loc.isEmpty) loc = 'Mandi Hub, Rajasthan';

    return SellerOfferPriceRevision(
      offerId: item.id,
      lotNumber: item.lotNumber,
      sellerCompanyId: item.sellerCompanyId,
      sellerCompanyName: item.sellerCompanyName,
      commodityId: item.commodityId,
      commodityName: item.commodityName,
      gradeId: item.gradeId,
      gradeName: item.gradeName,
      askingPrice: item.askingPrice,
      unitSymbol: item.unitSymbol,
      availableQuantity: item.availableQuantity,
      location: loc,
      version: item.version,
      priceUpdatedAt: item.createdAt,
      isEligible: item.status.isEligibleForMatching && !item.isExpired,
    );
  }

  /// Revision fingerprint for tamper and staleness detection.
  String get revisionFingerprint =>
      '$offerId-v$version-${askingPrice.toStringAsFixed(2)}-${priceUpdatedAt.millisecondsSinceEpoch}';

  Map<String, dynamic> toSnapshotJson() {
    return {
      'offer_id': offerId,
      'lot_number': lotNumber,
      'seller_company_id': sellerCompanyId,
      'seller_company_name': sellerCompanyName,
      'commodity_id': commodityId,
      'commodity_name': commodityName,
      'grade_id': gradeId,
      'grade_name': gradeName,
      'price': askingPrice,
      'unit': unitSymbol,
      'available_quantity': availableQuantity,
      'location': location,
      'version': version,
      'price_updated_at': priceUpdatedAt.toIso8601String(),
    };
  }

  factory SellerOfferPriceRevision.fromSnapshotJson(Map<String, dynamic> json) {
    return SellerOfferPriceRevision(
      offerId: json['offer_id']?.toString() ?? '',
      lotNumber: json['lot_number']?.toString() ?? '',
      sellerCompanyId: json['seller_company_id']?.toString() ?? '',
      sellerCompanyName: json['seller_company_name']?.toString() ?? '',
      commodityId: json['commodity_id']?.toString() ?? '',
      commodityName: json['commodity_name']?.toString() ?? '',
      gradeId: json['grade_id']?.toString() ?? '',
      gradeName: json['grade_name']?.toString() ?? '',
      askingPrice: (json['price'] as num? ?? 0).toDouble(),
      unitSymbol: json['unit']?.toString() ?? 'MT',
      availableQuantity: (json['available_quantity'] as num? ?? 0).toDouble(),
      location: json['location']?.toString() ?? '',
      version: (json['version'] as num? ?? 1).toInt(),
      priceUpdatedAt: json['price_updated_at'] != null
          ? (DateTime.tryParse(json['price_updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      isEligible: true,
    );
  }
}

/// Representation of an intended buyer recipient.
@immutable
class BuyerRecipient {
  final String userId;
  final String companyId;
  final String name;
  final String companyName;
  final String mobile;
  final bool isVerified;

  const BuyerRecipient({
    required this.userId,
    required this.companyId,
    required this.name,
    required this.companyName,
    required this.mobile,
    this.isVerified = true,
  });

  factory BuyerRecipient.fromContact(DirectoryContact contact) {
    return BuyerRecipient(
      userId: contact.userId.isNotEmpty ? contact.userId : contact.id,
      companyId: contact.companyId,
      name: contact.name,
      companyName: contact.companyName,
      mobile: contact.formattedMobile,
      isVerified: contact.isVerified,
    );
  }
}

/// Result of evaluating price snapshot staleness.
class PriceValidationResult {
  final bool isValid;
  final List<String> changedOfferIds;
  final List<String> staleDescriptions;
  final List<SellerOfferPriceRevision> refreshedOffers;

  const PriceValidationResult({
    required this.isValid,
    this.changedOfferIds = const [],
    this.staleDescriptions = const [],
    this.refreshedOffers = const [],
  });

  bool get hasPriceDrift => !isValid && changedOfferIds.isNotEmpty;
}

/// Draft of a market price broadcast awaiting final confirmation.
@immutable
class BroadcastDraft {
  final String broadcastId;
  final String brokerId;
  final String brokerName;
  final String brokerageName;
  final List<BuyerRecipient> recipients;
  final List<SellerOfferPriceRevision> offers;
  final String generatedMessage;
  final DateTime createdAt;

  const BroadcastDraft({
    required this.broadcastId,
    required this.brokerId,
    required this.brokerName,
    required this.brokerageName,
    required this.recipients,
    required this.offers,
    required this.generatedMessage,
    required this.createdAt,
  });

  /// Generate standardized market price update message.
  static String buildStandardMessage({
    required String brokerageName,
    required String brokerName,
    required List<SellerOfferPriceRevision> offers,
    DateTime? effectiveDate,
  }) {
    final date = effectiveDate ?? DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    final buffer = StringBuffer();

    buffer.writeln('MARKET PRICE UPDATE');
    buffer.writeln('');
    buffer.writeln('Date: $dateStr');
    if (brokerageName.isNotEmpty) {
      buffer.writeln('Brokerage: $brokerageName');
    }
    buffer.writeln('');
    buffer.writeln('Available market offers:');
    buffer.writeln('');

    final f = NumberFormat('#,##,###.##', 'en_IN');

    for (int i = 0; i < offers.length; i++) {
      final o = offers[i];
      final itemDate = DateFormat('dd MMM, hh:mm a').format(o.priceUpdatedAt);
      buffer.writeln('${i + 1}. ${o.commodityName} (${o.gradeName})');
      buffer.writeln('   Price: ₹${f.format(o.askingPrice)} / ${o.unitSymbol}');
      buffer.writeln('   Seller: ${o.sellerCompanyName}');
      buffer.writeln('   Availability: ${f.format(o.availableQuantity)} ${o.unitSymbol}');
      buffer.writeln('   Price updated: $itemDate (v${o.version})');
      if (o.location.isNotEmpty) {
        buffer.writeln('   Location: ${o.location}');
      }
      buffer.writeln('');
    }

    buffer.writeln('For current availability, final pricing, and order coordination, please contact your broker.');
    if (brokerName.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Authorized Desk: $brokerName');
    }

    return buffer.toString().trim();
  }
}

/// Delivery outcome of the market price broadcast.
class BroadcastOutcome {
  final String broadcastId;
  final int totalIntended;
  final int successfulDeliveryCount;
  final int failedDeliveryCount;
  final List<String> successfulRecipientNames;
  final List<String> failedRecipientNames;
  final DateTime sentAt;
  final List<SellerOfferPriceRevision> sentPriceSnapshot;
  final String finalMessage;

  const BroadcastOutcome({
    required this.broadcastId,
    required this.totalIntended,
    required this.successfulDeliveryCount,
    required this.failedDeliveryCount,
    required this.successfulRecipientNames,
    required this.failedRecipientNames,
    required this.sentAt,
    required this.sentPriceSnapshot,
    required this.finalMessage,
  });

  bool get isFullSuccess =>
      failedDeliveryCount == 0 && successfulDeliveryCount > 0;
  bool get isPartialSuccess =>
      successfulDeliveryCount > 0 && failedDeliveryCount > 0;
}
