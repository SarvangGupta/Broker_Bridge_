import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'package:rmbroker_mobile/features/commission/domain/commission_calculator.dart';
import 'package:rmbroker_mobile/features/invoices/domain/statement_model.dart';

/// Clean document preview modal for broker financial statements across a date range.
class StatementDocumentPreview extends StatelessWidget {
  final CommissionStatement statement;

  const StatementDocumentPreview({
    super.key,
    required this.statement,
  });

  static Future<void> show(BuildContext context, {required CommissionStatement statement}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatementDocumentPreview(statement: statement),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('     RMBROKER INTERMEDIARY DESK');
    buffer.writeln('    JAIPUR MANDI COMMODITY EXCHANGE');
    buffer.writeln('       BROKER FINANCIAL STATEMENT');
    buffer.writeln('========================================');
    buffer.writeln('Statement No: ${statement.statementNumber}');
    buffer.writeln('Period: ${dateFormat.format(statement.startDate)} to ${dateFormat.format(statement.endDate)}');
    buffer.writeln('Generated: ${dateFormat.format(statement.generatedAt)}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Opening Balance: ₹${statement.openingBalance.toStringAsFixed(2)}');
    buffer.writeln('Commission Invoiced: +₹${statement.totalCommissionInvoiced.toStringAsFixed(2)}');
    buffer.writeln('Payments Received: -₹${statement.totalPaymentsReceived.toStringAsFixed(2)}');
    buffer.writeln('Credits & Adjustments: -₹${statement.totalCreditsAndAdjustments.toStringAsFixed(2)}');
    buffer.writeln('Disputed Escrow Withheld: ₹${statement.totalDisputedAmount.toStringAsFixed(2)}');
    buffer.writeln('CLOSING OUTSTANDING BALANCE: ₹${statement.closingOutstandingBalance.toStringAsFixed(2)}');
    buffer.writeln('========================================');
    buffer.writeln('TRANSACTION LEDGER:');
    for (final item in statement.items) {
      buffer.writeln('${dateFormat.format(item.date)} | ${item.reference} | ${item.type.displayLabel} | Dr: ₹${item.debit.toStringAsFixed(2)} | Cr: ₹${item.credit.toStringAsFixed(2)} | Bal: ₹${item.runningBalance.toStringAsFixed(2)}');
    }
    buffer.writeln('========================================');
    buffer.writeln(statement.fiduciaryDisclosure);

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Financial statement copied to clipboard!'),
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

              // Title Bar
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
                        'Broker Statement Preview',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.copy, size: 18),
                        tooltip: 'Copy Statement',
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

              // Document Box
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
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statement.brokerDeskName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                statement.mandiHub,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                              ),
                              const Text(
                                'Brokerage Financial Statement',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statement.statementNumber,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1.5),

                    // Period & Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('REPORTING PERIOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight)),
                            const SizedBox(height: 2),
                            Text(
                              '${dateFormat.format(statement.startDate)} – ${dateFormat.format(statement.endDate)}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('GENERATED DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight)),
                            const SizedBox(height: 2),
                            Text(
                              dateFormat.format(statement.generatedAt),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Financial Balance Summary Grid
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _StatementMetricLine(
                            label: 'Opening Balance (Receivable)',
                            amount: statement.openingBalance,
                          ),
                          _StatementMetricLine(
                            label: 'Total Commission Invoiced (+)',
                            amount: statement.totalCommissionInvoiced,
                            color: AppColors.primary,
                          ),
                          _StatementMetricLine(
                            label: 'Payments Received (-)',
                            amount: statement.totalPaymentsReceived,
                            color: AppColors.success,
                            isNegative: true,
                          ),
                          if (statement.totalCreditsAndAdjustments > 0)
                            _StatementMetricLine(
                              label: 'Credits & Adjustments (-)',
                              amount: statement.totalCreditsAndAdjustments,
                              color: const Color(0xFF9333EA),
                              isNegative: true,
                            ),
                          const Divider(height: 12),
                          _StatementMetricLine(
                            label: 'CLOSING OUTSTANDING BALANCE',
                            amount: statement.closingOutstandingBalance,
                            isTotal: true,
                            color: statement.closingOutstandingBalance > 0
                                ? AppColors.error
                                : AppColors.success,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Transaction Items Table Header
                    const Text(
                      'STATEMENT TRANSACTION LEDGER',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 2, child: Text('DATE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800))),
                          Expanded(flex: 3, child: Text('REFERENCE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800))),
                          Expanded(flex: 2, child: Text('DEBIT (+)', textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800))),
                          Expanded(flex: 2, child: Text('CREDIT (-)', textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800))),
                          Expanded(flex: 2, child: Text('BALANCE', textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    if (statement.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No transactions recorded in selected period.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                        ),
                      )
                    else
                      ...statement.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    DateFormat('dd/MM').format(item.date),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.reference,
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        item.counterparty,
                                        style: const TextStyle(fontSize: 9, color: AppColors.textSecondaryLight),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.debit > 0 ? CommissionCalculator.formatCurrency(item.debit) : '-',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.credit > 0 ? CommissionCalculator.formatCurrency(item.credit) : '-',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    CommissionCalculator.formatCurrency(item.runningBalance),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          )),

                    const SizedBox(height: 18),

                    // Statutory Disclaimer
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        statement.fiduciaryDisclosure,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF92400E), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bottom Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.share2, size: 16),
                  label: const Text('Share Financial Statement / Copy'),
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

class _StatementMetricLine extends StatelessWidget {
  final String label;
  final double amount;
  final Color? color;
  final bool isNegative;
  final bool isTotal;

  const _StatementMetricLine({
    required this.label,
    required this.amount,
    this.color,
    this.isNegative = false,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 12 : 11,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.textPrimaryLight,
            ),
          ),
          Text(
            '${isNegative ? '-' : ''}${CommissionCalculator.formatCurrency(amount)}',
            style: TextStyle(
              fontSize: isTotal ? 13.5 : 11.5,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
              color: color ?? AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
