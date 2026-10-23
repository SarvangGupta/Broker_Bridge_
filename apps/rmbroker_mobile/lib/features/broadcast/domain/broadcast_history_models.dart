import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'market_broadcast_models.dart';

/// Recipient offer snapshot communicating exact price and commodity terms.
@immutable
class RecipientOfferSnapshot {
  final String commodityName;
  final String gradeName;
  final String sellerCompanyName;
  final double price;
  final String unitSymbol;
  final int version;
  final DateTime priceUpdatedAt;

  const RecipientOfferSnapshot({
    required this.commodityName,
    required this.gradeName,
    required this.sellerCompanyName,
    required this.price,
    required this.unitSymbol,
    required this.version,
    required this.priceUpdatedAt,
  });

  factory RecipientOfferSnapshot.fromRevision(SellerOfferPriceRevision rev) {
    return RecipientOfferSnapshot(
      commodityName: rev.commodityName,
      gradeName: rev.gradeName,
      sellerCompanyName: rev.sellerCompanyName,
      price: rev.askingPrice,
      unitSymbol: rev.unitSymbol,
      version: rev.version,
      priceUpdatedAt: rev.priceUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'commodity_name': commodityName,
        'grade_name': gradeName,
        'seller_company_name': sellerCompanyName,
        'price': price,
        'unit_symbol': unitSymbol,
        'version': version,
        'price_updated_at': priceUpdatedAt.toIso8601String(),
      };

  factory RecipientOfferSnapshot.fromJson(Map<String, dynamic> json) {
    return RecipientOfferSnapshot(
      commodityName: json['commodity_name']?.toString() ?? '',
      gradeName: json['grade_name']?.toString() ?? '',
      sellerCompanyName: json['seller_company_name']?.toString() ?? '',
      price: (json['price'] as num? ?? 0).toDouble(),
      unitSymbol: json['unit_symbol']?.toString() ?? 'MT',
      version: (json['version'] as num? ?? 1).toInt(),
      priceUpdatedAt: json['price_updated_at'] != null
          ? (DateTime.tryParse(json['price_updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// Delivery status for a broadcast recipient.
enum BroadcastDeliveryStatus {
  created('Created', 'Queued for dispatch'),
  sent('Sent', 'Dispatched to buyer app notification queue'),
  delivered('Delivered', 'Delivered to buyer device'),
  read('Read', 'Opened and read by buyer'),
  failed('Failed', 'Delivery failed or rejected');

  final String label;
  final String description;
  const BroadcastDeliveryStatus(this.label, this.description);

  static BroadcastDeliveryStatus fromString(String? val) {
    if (val == null) return BroadcastDeliveryStatus.sent;
    switch (val.toLowerCase().trim()) {
      case 'read':
        return BroadcastDeliveryStatus.read;
      case 'delivered':
        return BroadcastDeliveryStatus.delivered;
      case 'failed':
      case 'error':
        return BroadcastDeliveryStatus.failed;
      case 'created':
      case 'pending':
        return BroadcastDeliveryStatus.created;
      case 'sent':
      default:
        return BroadcastDeliveryStatus.sent;
    }
  }
}

/// Detailed historical record for an individual recipient in a broadcast.
@immutable
class BroadcastRecipientDetail {
  final String recipientUserId;
  final String buyerName;
  final String companyName;
  final String mobile;
  final BroadcastDeliveryStatus deliveryStatus;
  final DateTime sentAt;
  final DateTime? readAt;
  final String? failureReason;
  final String? notificationId;
  final List<RecipientOfferSnapshot> items;

  const BroadcastRecipientDetail({
    required this.recipientUserId,
    required this.buyerName,
    required this.companyName,
    required this.mobile,
    required this.deliveryStatus,
    required this.sentAt,
    this.readAt,
    this.failureReason,
    this.notificationId,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'recipient_user_id': recipientUserId,
        'buyer_name': buyerName,
        'company_name': companyName,
        'mobile': mobile,
        'delivery_status': deliveryStatus.name,
        'sent_at': sentAt.toIso8601String(),
        'read_at': readAt?.toIso8601String(),
        'failure_reason': failureReason,
        'notification_id': notificationId,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory BroadcastRecipientDetail.fromJson(Map<String, dynamic> json) {
    return BroadcastRecipientDetail(
      recipientUserId: json['recipient_user_id']?.toString() ?? '',
      buyerName: json['buyer_name']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      deliveryStatus: BroadcastDeliveryStatus.fromString(json['delivery_status']?.toString()),
      sentAt: json['sent_at'] != null
          ? (DateTime.tryParse(json['sent_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      failureReason: json['failure_reason']?.toString(),
      notificationId: json['notification_id']?.toString(),
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(RecipientOfferSnapshot.fromJson)
          .toList(),
    );
  }
}

/// Comprehensive, immutable historical record of a single sent market price broadcast.
@immutable
class BroadcastHistoryItem {
  final String id; // Unique reference ID (e.g. BC-2026-1023-001)
  final String brokerId; // Enforces tenant/broker authorization
  final String brokerName;
  final String brokerageName;
  final DateTime sentAt;
  final int totalRecipients;
  final int successfulCount;
  final int failedCount;
  final List<SellerOfferPriceRevision> priceSnapshots; // Immutable prices as sent
  final List<BroadcastRecipientDetail> recipients;
  final String fullMessage;
  final String? deliveryStatusSummary;

  const BroadcastHistoryItem({
    required this.id,
    required this.brokerId,
    required this.brokerName,
    required this.brokerageName,
    required this.sentAt,
    required this.totalRecipients,
    required this.successfulCount,
    required this.failedCount,
    required this.priceSnapshots,
    required this.recipients,
    required this.fullMessage,
    this.deliveryStatusSummary,
  });

  /// All unique commodities sent in this broadcast.
  List<String> get commodityNames =>
      priceSnapshots.map((p) => p.commodityName).toSet().toList();

  /// Minimum asking price in this broadcast snapshot.
  double get minPrice {
    if (priceSnapshots.isEmpty) return 0.0;
    return priceSnapshots.map((p) => p.askingPrice).reduce((a, b) => a < b ? a : b);
  }

  /// Maximum asking price in this broadcast snapshot.
  double get maxPrice {
    if (priceSnapshots.isEmpty) return 0.0;
    return priceSnapshots.map((p) => p.askingPrice).reduce((a, b) => a > b ? a : b);
  }

  bool get isFullSuccess => failedCount == 0 && successfulCount > 0;
  bool get hasFailure => failedCount > 0;

  String get formattedSentAt => DateFormat('dd MMM yyyy, hh:mm a').format(sentAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'broker_id': brokerId,
        'broker_name': brokerName,
        'brokerage_name': brokerageName,
        'sent_at': sentAt.toIso8601String(),
        'total_recipients': totalRecipients,
        'successful_count': successfulCount,
        'failed_count': failedCount,
        'price_snapshots': priceSnapshots.map((p) => p.toSnapshotJson()).toList(),
        'recipients': recipients.map((r) => r.toJson()).toList(),
        'full_message': fullMessage,
        'delivery_status_summary': deliveryStatusSummary,
      };

  factory BroadcastHistoryItem.fromJson(Map<String, dynamic> json) {
    final snapshots = (json['price_snapshots'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SellerOfferPriceRevision.fromSnapshotJson)
        .toList();

    final recipients = (json['recipients'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(BroadcastRecipientDetail.fromJson)
        .toList();

    return BroadcastHistoryItem(
      id: json['id']?.toString() ?? '',
      brokerId: json['broker_id']?.toString() ?? '',
      brokerName: json['broker_name']?.toString() ?? '',
      brokerageName: json['brokerage_name']?.toString() ?? '',
      sentAt: json['sent_at'] != null
          ? (DateTime.tryParse(json['sent_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      totalRecipients: (json['total_recipients'] as num? ?? recipients.length).toInt(),
      successfulCount: (json['successful_count'] as num? ?? recipients.length).toInt(),
      failedCount: (json['failed_count'] as num? ?? 0).toInt(),
      priceSnapshots: snapshots,
      recipients: recipients,
      fullMessage: json['full_message']?.toString() ?? '',
      deliveryStatusSummary: json['delivery_status_summary']?.toString(),
    );
  }
}

/// Date range presets for filtering broadcast history.
enum HistoryDateFilter {
  all('All Time'),
  today('Today'),
  last7Days('Last 7 Days'),
  last30Days('Last 30 Days'),
  custom('Custom Range');

  final String label;
  const HistoryDateFilter(this.label);
}

/// Filter criteria model for querying broadcast history.
@immutable
class BroadcastHistoryFilter {
  final HistoryDateFilter dateFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? buyerSearch;
  final String? commodity;
  final double? minPrice;
  final double? maxPrice;
  final BroadcastDeliveryStatus? status;
  final String? searchQuery;

  const BroadcastHistoryFilter({
    this.dateFilter = HistoryDateFilter.all,
    this.customStartDate,
    this.customEndDate,
    this.buyerSearch,
    this.commodity,
    this.minPrice,
    this.maxPrice,
    this.status,
    this.searchQuery,
  });

  bool get hasActiveFilters =>
      dateFilter != HistoryDateFilter.all ||
      (buyerSearch != null && buyerSearch!.trim().isNotEmpty) ||
      (commodity != null && commodity != 'All') ||
      minPrice != null ||
      maxPrice != null ||
      status != null ||
      (searchQuery != null && searchQuery!.trim().isNotEmpty);

  int get activeFilterCount {
    int count = 0;
    if (dateFilter != HistoryDateFilter.all) count++;
    if (buyerSearch != null && buyerSearch!.trim().isNotEmpty) count++;
    if (commodity != null && commodity != 'All') count++;
    if (minPrice != null || maxPrice != null) count++;
    if (status != null) count++;
    if (searchQuery != null && searchQuery!.trim().isNotEmpty) count++;
    return count;
  }

  BroadcastHistoryFilter copyWith({
    HistoryDateFilter? dateFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? buyerSearch,
    String? commodity,
    double? minPrice,
    double? maxPrice,
    BroadcastDeliveryStatus? status,
    String? searchQuery,
    bool clearDates = false,
    bool clearBuyer = false,
    bool clearCommodity = false,
    bool clearPrice = false,
    bool clearStatus = false,
    bool clearSearch = false,
  }) {
    return BroadcastHistoryFilter(
      dateFilter: dateFilter ?? this.dateFilter,
      customStartDate: clearDates ? null : (customStartDate ?? this.customStartDate),
      customEndDate: clearDates ? null : (customEndDate ?? this.customEndDate),
      buyerSearch: clearBuyer ? null : (buyerSearch ?? this.buyerSearch),
      commodity: clearCommodity ? null : (commodity ?? this.commodity),
      minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      status: clearStatus ? null : (status ?? this.status),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
    );
  }
}
