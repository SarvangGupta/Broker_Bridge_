import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../directory/domain/cheque_leaf_data.dart';
import 'deal_model.dart';

/// Comprehensive Order / Deal Summary for deal confirmation and document sharing.
@immutable
class DealOrderSummary {
  final String dealId;
  final String dealRef;
  final String commodity;
  final String? grade;
  final double quantity;
  final String unit;
  final double agreedPrice;
  final double totalValue;
  final String deliveryLocation;
  final String deliveryTerms;
  final String paymentTerms;
  final String priceBasis;
  final String packagingType;
  final String sellerCompanyName;
  final String sellerCompanyId;
  final String buyerCompanyName;
  final String buyerCompanyId;
  final ChequeLeafData? sellerBankDetails;
  final bool hasSellerChequeLeaf;
  final String? sellerChequeUrl;
  final bool isChequeSharingAuthorized;
  final DateTime? sharedAt;

  const DealOrderSummary({
    required this.dealId,
    required this.dealRef,
    required this.commodity,
    this.grade,
    required this.quantity,
    required this.unit,
    required this.agreedPrice,
    required this.totalValue,
    required this.deliveryLocation,
    required this.deliveryTerms,
    required this.paymentTerms,
    required this.priceBasis,
    required this.packagingType,
    required this.sellerCompanyName,
    required this.sellerCompanyId,
    required this.buyerCompanyName,
    required this.buyerCompanyId,
    this.sellerBankDetails,
    this.hasSellerChequeLeaf = false,
    this.sellerChequeUrl,
    this.isChequeSharingAuthorized = false,
    this.sharedAt,
  });

  factory DealOrderSummary.fromDealDetail(
    DealDetailItem detail, {
    ChequeLeafData? sellerBank,
    bool authorizeChequeSharing = false,
  }) {
    final deal = detail.deal;
    final hasCheque = sellerBank != null &&
        (sellerBank.documentPath != null ||
            (sellerBank.accountNumber != null && sellerBank.accountNumber!.isNotEmpty));

    return DealOrderSummary(
      dealId: deal.id,
      dealRef: deal.ref,
      commodity: deal.commodityName,
      grade: deal.gradeName,
      quantity: deal.agreedQuantity,
      unit: deal.unitSymbol,
      agreedPrice: deal.agreedPrice,
      totalValue: deal.totalValuation,
      deliveryLocation: deal.deliveryLocation ?? 'FOR Mandi Warehouse',
      deliveryTerms: detail.deliveryTerms,
      paymentTerms: detail.paymentTerms,
      priceBasis: deal.priceBasis,
      packagingType: detail.packagingType,
      sellerCompanyName: deal.sellerCompanyName,
      sellerCompanyId: deal.sellerCompanyId,
      buyerCompanyName: deal.buyerCompanyName,
      buyerCompanyId: deal.buyerCompanyId,
      sellerBankDetails: sellerBank,
      hasSellerChequeLeaf: hasCheque,
      sellerChequeUrl: sellerBank?.documentPath,
      isChequeSharingAuthorized: authorizeChequeSharing,
    );
  }

  /// Formatted text representation for preview, SMS, WhatsApp, or formal order note.
  String toShareableText({bool includeAuthorizedBanking = false}) {
    final cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final buf = StringBuffer();

    buf.writeln('📋 *OFFICIAL DEAL SUMMARY & ORDER CONFIRMATION*');
    buf.writeln('Deal Reference: $dealRef');
    buf.writeln('Buyer: $buyerCompanyName');
    buf.writeln('Seller: $sellerCompanyName');
    buf.writeln('----------------------------------------');
    buf.writeln('Commodity: $commodity ${grade != null ? "($grade)" : ""}');
    buf.writeln('Volume: $quantity $unit');
    buf.writeln('Agreed Price: ${cur.format(agreedPrice)} / $unit');
    buf.writeln('Total Value: ${cur.format(totalValue)}');
    buf.writeln('----------------------------------------');
    buf.writeln('Price Basis: $priceBasis');
    buf.writeln('Delivery Location: $deliveryLocation');
    buf.writeln('Delivery Terms: $deliveryTerms');
    buf.writeln('Payment Terms: $paymentTerms');
    buf.writeln('Packaging: $packagingType');

    if (includeAuthorizedBanking && sellerBankDetails != null && hasSellerChequeLeaf) {
      buf.writeln('----------------------------------------');
      buf.writeln('🏦 *SELLER BANK DETAILS (CHEQUE LEAF SUPPORTED)*');
      if (sellerBankDetails!.accountHolderName != null) {
        buf.writeln('Account Holder: ${sellerBankDetails!.accountHolderName}');
      }
      if (sellerBankDetails!.bankName != null) {
        buf.writeln('Bank: ${sellerBankDetails!.bankName}');
      }
      buf.writeln('A/c No: ${sellerBankDetails!.maskedAccountNumber}');
      if (sellerBankDetails!.ifsc != null) {
        buf.writeln('IFSC: ${sellerBankDetails!.ifsc}');
      }
      if (sellerBankDetails!.branch != null) {
        buf.writeln('Branch: ${sellerBankDetails!.branch}');
      }
      buf.writeln('Notice: Cheque Leaf Provided — Broker Recorded (not bank verified).');
    }

    buf.writeln('----------------------------------------');
    buf.writeln('Fiduciary Mediation: Mediated securely via RMBroker Exchange.');

    return buf.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'dealId': dealId,
      'dealRef': dealRef,
      'commodity': commodity,
      'grade': grade,
      'quantity': quantity,
      'unit': unit,
      'agreedPrice': agreedPrice,
      'totalValue': totalValue,
      'deliveryLocation': deliveryLocation,
      'deliveryTerms': deliveryTerms,
      'paymentTerms': paymentTerms,
      'priceBasis': priceBasis,
      'packagingType': packagingType,
      'sellerCompanyName': sellerCompanyName,
      'sellerCompanyId': sellerCompanyId,
      'buyerCompanyName': buyerCompanyName,
      'buyerCompanyId': buyerCompanyId,
      'sellerBankDetails': sellerBankDetails?.toJson(),
      'hasSellerChequeLeaf': hasSellerChequeLeaf,
      'isChequeSharingAuthorized': isChequeSharingAuthorized,
      'sharedAt': sharedAt?.toIso8601String(),
    };
  }
}

