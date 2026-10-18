import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/features/commission/domain/commission_calculator.dart';
import 'package:rmbroker_mobile/features/invoices/domain/invoice_model.dart';

/// Clean document preview modal rendering an official Mandi Brokerage Commission Note.
class InvoiceDocumentPreview extends StatelessWidget {
  final CommissionInvoice invoice;

  const InvoiceDocumentPreview({
    super.key,
    required this.invoice,
  });

  static Future<void> show(BuildContext context, {required CommissionInvoice invoice}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InvoiceDocumentPreview(invoice: invoice),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('     RMBROKER INTERMEDIARY DESK');
    buffer.writeln('    JAIPUR MANDI COMMODITY EXCHANGE');
    buffer.writeln('       COMMISSION NOTE (INVOICE)');
    buffer.writeln('========================================');
    buffer.writeln('Invoice No: ${invoice.invoiceNumber}');
    buffer.writeln('Date of Issue: ${dateFormat.format(invoice.issueDate)}');
    buffer.writeln('Payment Due: ${dateFormat.format(invoice.dueDate)}');
    buffer.writeln('Status: ${invoice.status.displayLabel.toUpperCase()}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Billed To: ${invoice.billedToParty}');
    buffer.writeln('Buyer: ${invoice.buyerCompanyName}');
    buffer.writeln('Seller: ${invoice.sellerCompanyName}');
    buffer.writeln('Deal Reference: ${invoice.dealReference}');
    buffer.writeln('Booking Reference: ${invoice.bookingReference}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('COMMODITY: ${invoice.commodityName} (${invoice.gradeName})');
    buffer.writeln('Delivered & Accepted Qty: ${invoice.eligibleDeliveredQuantity.toStringAsFixed(1)} MT');
    buffer.writeln('Agreed Commission Rate: ₹${invoice.agreedRatePerMT.toStringAsFixed(0)} / ${invoice.calculationBasis}');
    buffer.writeln('Formula: ${invoice.calculationFormula}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Subtotal: ₹${invoice.subtotalAmount.toStringAsFixed(2)}');
    buffer.writeln('GST / Tax: ₹${invoice.taxAmount.toStringAsFixed(2)} (Direct Intermediary Note)');
    buffer.writeln('Total Invoiced: ₹${invoice.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('Paid Amount: ₹${invoice.paidAmount.toStringAsFixed(2)}');
    if (invoice.creditedAmount > 0) {
      buffer.writeln('Credit / Adjustment: -₹${invoice.creditedAmount.toStringAsFixed(2)}');
    }
    buffer.writeln('BALANCE DUE: ₹${invoice.outstandingAmount.toStringAsFixed(2)}');
    buffer.writeln('========================================');
    buffer.writeln('STATUTORY NOTICE: This invoice covers brokerage intermediary fees only.');
    buffer.writeln('Underlying raw-material trade amounts are payable directly between counterparties.');
    buffer.writeln('========================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invoice document text copied to clipboard!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sheet Actions Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(LucideIcons.arrowLeft, size: 22, color: AppColors.textPrimaryLight),
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Invoice Document Preview',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.copy, size: 18),
                        tooltip: 'Copy Text',
                        onPressed: () => _copyToClipboard(context),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 20),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Printable Document Container
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mandi Header & Branding
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RMBROKER COMMODITY DESK',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Jaipur Mandi Commodity Exchange Hub',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                            ),
                            Text(
                              'Authorized Agricultural Broker Intermediary',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            invoice.status.displayLabel.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1.5),

                    // Invoice Metadata Grid
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('INVOICE NUMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight)),
                              const SizedBox(height: 2),
                              Text(invoice.invoiceNumber, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 10),
                              const Text('DATE OF ISSUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight)),
                              const SizedBox(height: 2),
                              Text(dateFormat.format(invoice.issueDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PAYMENT DUE DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight)),
                              const SizedBox(height: 2),
                              Text(dateFormat.format(invoice.dueDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 10),
                              const Text('DEAL REFERENCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight)),
                              const SizedBox(height: 2),
                              Text('${invoice.dealReference} (${invoice.bookingReference})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Counterparty Details
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BILLED TO (PARTY)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight)),
                              const SizedBox(height: 2),
                              Text(
                                '${invoice.billedToParty}\n${invoice.billedToParty == 'Buyer Enterprise' ? invoice.buyerCompanyName : invoice.sellerCompanyName}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('COUNTERPARTY SELLER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight)),
                              const SizedBox(height: 2),
                              Text(
                                invoice.sellerCompanyName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Line Items Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                          Expanded(flex: 2, child: Text('DELIVERED QTY', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                          Expanded(flex: 2, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                          Expanded(flex: 2, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Line Items
                    ...invoice.lineItems.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  item.description,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '₹${item.unitRate.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  CommissionCalculator.formatCurrency(item.amount),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        )),
                    const Divider(height: 20),

                    // Financial Summary Rows
                    _DocumentSummaryRow(label: 'Subtotal Amount', value: CommissionCalculator.formatCurrency(invoice.subtotalAmount)),
                    _DocumentSummaryRow(
                      label: 'GST / Tax (Non-assumed)',
                      value: '₹${invoice.taxAmount.toStringAsFixed(2)}',
                      subtitle: 'Direct Intermediary Exemption / Non-assumed',
                    ),
                    if (invoice.creditedAmount > 0)
                      _DocumentSummaryRow(
                        label: 'Credit Note Adjustments',
                        value: '-${CommissionCalculator.formatCurrency(invoice.creditedAmount)}',
                        isNegative: true,
                      ),
                    const Divider(height: 14),
                    _DocumentSummaryRow(
                      label: 'Total Invoiced Due',
                      value: CommissionCalculator.formatCurrency(invoice.totalAmount),
                      isTotal: true,
                    ),
                    _DocumentSummaryRow(
                      label: 'Amount Paid to Date',
                      value: CommissionCalculator.formatCurrency(invoice.paidAmount),
                      isSuccess: true,
                    ),
                    const Divider(height: 14),
                    _DocumentSummaryRow(
                      label: 'NET OUTSTANDING BALANCE',
                      value: CommissionCalculator.formatCurrency(invoice.outstandingAmount),
                      isBalanceDue: true,
                    ),

                    if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'Remarks: ${invoice.notes}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Statutory Disclaimer
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STATUTORY FIDUCIARY NOTICE',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'This document is an authorized Brokerage Commission Note. It represents intermediary brokerage fees on accepted deliveries. Raw-material payments are payable directly between buyer and seller. This is not an authorized GST tax invoice under Section 31 CGST Act unless statutory GSTIN is configured.',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF92400E), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bottom Sharing Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.share2, size: 16),
                  label: const Text('Share Invoice Document / Text'),
                  onPressed: () => _copyToClipboard(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DocumentSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final bool isTotal;
  final bool isBalanceDue;
  final bool isNegative;
  final bool isSuccess;

  const _DocumentSummaryRow({
    required this.label,
    required this.value,
    this.subtitle,
    this.isTotal = false,
    this.isBalanceDue = false,
    this.isNegative = false,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    Color valueColor = AppColors.textPrimaryLight;
    if (isBalanceDue) valueColor = AppColors.error;
    if (isSuccess) valueColor = AppColors.success;
    if (isNegative) valueColor = const Color(0xFF9333EA);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isBalanceDue || isTotal ? 12 : 11,
                  fontWeight: isBalanceDue || isTotal ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondaryLight),
                ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBalanceDue ? 14 : (isTotal ? 13 : 11.5),
              fontWeight: isBalanceDue || isTotal ? FontWeight.w800 : FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
