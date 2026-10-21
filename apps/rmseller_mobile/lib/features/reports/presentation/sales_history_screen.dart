import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/seller_reports_repository.dart';
import '../domain/sales_report_model.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final SellerReportsRepository _repository = SellerReportsRepository();
  String _selectedTimeframe = 'Monthly';
  String _selectedStatus = 'ALL';
  bool _isLoading = true;

  DateTime? _customStartDate;
  DateTime? _customEndDate;

  SalesReportSummary? _summary;
  List<SalesTransactionItem> _transactions = [];

  final List<String> _timeframes = ['Weekly', 'Monthly', 'Quarterly', 'Yearly', 'Custom'];
  final List<String> _statusFilters = ['ALL', 'Completed', 'Active', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    final summary = await _repository.getSalesSummary(
      timeframe: _selectedTimeframe,
      customStart: _customStartDate,
      customEnd: _customEndDate,
    );
    final txs = await _repository.getTransactionHistory(
      timeframe: _selectedTimeframe,
      statusFilter: _selectedStatus,
      customStart: _customStartDate,
      customEnd: _customEndDate,
    );

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _transactions = txs;
      _isLoading = false;
    });
  }

  Future<void> _openCustomDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 14)),
              end: DateTime.now(),
            ),
    );

    if (picked != null) {
      setState(() {
        _selectedTimeframe = 'Custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _loadReportData();
    }
  }

  void _handleExportStatement() {
    final summary = _summary;
    if (summary == null) return;
    final dateFormat = DateFormat('dd MMM yyyy');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(LucideIcons.download, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Export Sales Statement'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reporting Period: ${summary.period}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                'Range: ${dateFormat.format(summary.startDate)} - ${dateFormat.format(summary.endDate)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              ),
              const Divider(height: 16),
              Text('Total Volume Sold: ${summary.totalSoldVolumeMT} MT'),
              Text('Gross Sales Value: ₹${summary.grossSalesValue.toStringAsFixed(0)}'),
              Text('Total Agreed Commission: ₹${summary.totalAgreedCommission.toStringAsFixed(0)}'),
              Text('Outstanding Commission: ₹${summary.totalCommissionOutstanding.toStringAsFixed(0)}'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6)),
                child: const Text(
                  'Counterparty Shield Notice: In accordance with Mandi trade privacy regulations, exports exclude Buyer contact details.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Financial statement exported securely.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Download PDF Statement', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Sales History & Financials'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: 'Export Statement',
            onPressed: _handleExportStatement,
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Refresh Reports',
            onPressed: _loadReportData,
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoadingIndicator(message: 'Compiling sales & settlement metrics...')
          : RefreshIndicator(
              onRefresh: _loadReportData,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Reporting Period Selector
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _timeframes.map((tf) {
                              final isSelected = _selectedTimeframe == tf;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(tf == 'Custom' && _customStartDate != null ? 'Custom Period' : tf),
                                  selected: isSelected,
                                  selectedColor: AppColors.primaryContainer,
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    fontSize: 12,
                                  ),
                                  onSelected: (val) {
                                    if (tf == 'Custom') {
                                      _openCustomDateRangePicker();
                                    } else if (val) {
                                      setState(() => _selectedTimeframe = tf);
                                      _loadReportData();
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sales Summary Cards
                  if (_summary != null) ...[
                    // Primary Gross Revenue Card
                    AppCard(
                      backgroundColor: AppColors.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Gross Sales Revenue (Completed)',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  _summary!.period,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹${_summary!.grossSalesValue.toStringAsFixed(0)}',
                            style: AppTypography.displayLarge.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Sold Volume: ${_summary!.totalSoldVolumeMT} MT',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${_summary!.completedDealsCount} Completed Deals',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Receivables & Invoices Card
                    Row(
                      children: [
                        Expanded(
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Settled Receivables', style: TextStyle(fontSize: 11, color: AppColors.textMutedLight)),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${_summary!.settledAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.success),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pending Invoices', style: TextStyle(fontSize: 11, color: AppColors.textMutedLight)),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${_summary!.pendingAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.warning),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Commission Summary Card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Broker Commission Breakdown', style: AppTypography.titleSmall),
                              Text(
                                '${_summary!.period} Summary',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetricColumn('Total Agreed Comm.', '₹${_summary!.totalAgreedCommission.toStringAsFixed(0)}'),
                              _buildMetricColumn('Commission Paid', '₹${_summary!.totalCommissionPaid.toStringAsFixed(0)}', color: AppColors.success),
                              _buildMetricColumn('Outstanding Comm.', '₹${_summary!.totalCommissionOutstanding.toStringAsFixed(0)}', color: AppColors.warning),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Transaction Status Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statusFilters.map((st) {
                        final isSelected = _selectedStatus == st;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(st == 'ALL' ? 'All Transactions' : st),
                            selected: isSelected,
                            selectedColor: AppColors.primaryContainer,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _selectedStatus = st);
                                _loadReportData();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Verified Transactions List
                  if (_transactions.isEmpty) ...[
                    AppEmptyState(
                      title: 'No Transactions In Period',
                      message: 'No commercial sales records found matching the $_selectedTimeframe timeframe and $_selectedStatus filter.',
                    ),
                  ] else ...[
                    ..._transactions.map((tx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          onTap: () {
                            context.push('/deals/${tx.dealId}');
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(tx.commodityName, style: AppTypography.titleSmall),
                                  ),
                                  StatusBadge(status: tx.status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${tx.bookingReference} • ${dateFormat.format(tx.date)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                              ),
                              const Divider(height: 18),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${tx.quantityMT} MT @ ₹${tx.ratePerMT.toStringAsFixed(0)} / MT',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '₹${tx.grossAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Invoice & Commission badges row
                              Row(
                                children: [
                                  if (tx.invoiceNo != null) ...[
                                    InkWell(
                                      onTap: () => context.push('/invoices/${tx.invoiceId ?? tx.invoiceNo!}'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(LucideIcons.receipt, size: 10, color: AppColors.primary),
                                            const SizedBox(width: 4),
                                            Text(
                                              tx.invoiceNo!,
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (tx.commissionAmount > 0) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.amber.shade200),
                                      ),
                                      child: Text(
                                        'Comm: ₹${tx.commissionAmount.toStringAsFixed(0)} (${tx.commissionPaid >= tx.commissionAmount ? "Paid" : "Pending"})',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),

                              Row(
                                children: [
                                  const Icon(LucideIcons.briefcase, size: 12, color: AppColors.secondary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      tx.brokerDeskName,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.textMutedLight),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMutedLight)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color ?? AppColors.textPrimaryLight),
        ),
      ],
    );
  }
}
