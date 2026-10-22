import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/seller_invoices_repository.dart';
import '../domain/seller_invoice_model.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  final String invoiceId;
  final SellerInvoice? initialInvoice;

  const InvoiceDetailsScreen({
    super.key,
    required this.invoiceId,
    this.initialInvoice,
  });

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  final SellerInvoicesRepository _repository = SellerInvoicesRepository();

  SellerInvoice? _invoice;
  List<SellerDocument> _documents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialInvoice != null) {
      _invoice = widget.initialInvoice;
      _isLoading = false;
      _loadSupportingDocuments(widget.initialInvoice!.dealId);
    } else {
      _loadInvoice();
    }
  }

  Future<void> _loadInvoice() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final inv = await _repository.getInvoiceById(widget.invoiceId);
      if (inv != null) {
        final docs = await _repository.getDocumentsForDeal(inv.dealId);
        if (!mounted) return;
        setState(() {
          _invoice = inv;
          _documents = docs;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Invoice record not found or inaccessible.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load invoice: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSupportingDocuments(String dealId) async {
    try {
      final docs = await _repository.getDocumentsForDeal(dealId);
      if (mounted) setState(() => _documents = docs);
    } catch (_) {}
  }

  Future<void> _handleDownload(String url, String fileName) async {
    final launched = await _repository.openDocument(url);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document "$fileName" opened in external viewer.'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppLoadingIndicator(
          message: 'Loading verified invoice statement...',
        ),
      );
    }

    if (_errorMessage != null || _invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice Details')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.receipt,
                size: 48,
                color: AppColors.textMutedLight,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Invoice record not available',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Retry',
                onPressed: _loadInvoice,
                variant: ButtonVariant.outline,
              ),
            ],
          ),
        ),
      );
    }

    final invoice = _invoice!;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(invoice.invoiceNo),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: 'Download Invoice PDF',
            onPressed: () =>
                _handleDownload(invoice.fileUrl, '${invoice.invoiceNo}.pdf'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Invoice Header Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TAX INVOICE',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          invoice.invoiceNo,
                          style: AppTypography.titleLarge,
                        ),
                      ],
                    ),
                    StatusBadge(status: invoice.status),
                  ],
                ),
                const Divider(height: 24),

                _buildDetailRow(
                  'Invoice Date:',
                  dateFormat.format(invoice.createdAt),
                ),
                if (invoice.dueDate != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Due Date:',
                    dateFormat.format(invoice.dueDate!),
                  ),
                ],
                if (invoice.bookingReference != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Deal Booking ID:',
                    invoice.bookingReference!,
                  ),
                ],
                const SizedBox(height: 8),
                _buildDetailRow('Deal Reference:', invoice.dealId),
                const SizedBox(height: 8),
                _buildDetailRow('Mediating Broker:', invoice.brokerDeskName),
                if (invoice.paymentReference != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Payment UTR / Ref:',
                    invoice.paymentReference!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Line Items & Financial Breakdown Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Commercial Line Items', style: AppTypography.titleMedium),
                const SizedBox(height: 12),

                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Commodity / Grade',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Qty',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Rate',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Amount (₹)',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice.commodityName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              invoice.gradeName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${invoice.quantity} ${invoice.unit}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '₹${invoice.ratePerUnit.toStringAsFixed(0)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          '₹${invoice.taxableAmount.toStringAsFixed(0)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),

                // Financial Totals
                _buildSummaryLine(
                  'Taxable Gross Amount:',
                  '₹${invoice.taxableAmount.toStringAsFixed(0)}',
                ),
                const SizedBox(height: 6),
                _buildSummaryLine(
                  'CGST (${(invoice.gstRate * 50).toStringAsFixed(1)}%):',
                  '₹${(invoice.gstAmount / 2).toStringAsFixed(0)}',
                ),
                const SizedBox(height: 6),
                _buildSummaryLine(
                  'SGST (${(invoice.gstRate * 50).toStringAsFixed(1)}%):',
                  '₹${(invoice.gstAmount / 2).toStringAsFixed(0)}',
                ),
                const Divider(height: 18),
                _buildSummaryLine(
                  'Total Invoice Value (Incl. Tax):',
                  '₹${invoice.totalWithTax.toStringAsFixed(0)}',
                  isBold: true,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Counterparty Shield & Broker Mediation Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.shieldCheck,
                  size: 20,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Broker-Mediated Counterparty Shield Active',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Commercial trade settlement and invoices are routed exclusively through your authorized Mandi Broker Desk. Direct counterparty contacts remain shielded.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Supporting Deal Documents Section
          if (_documents.isNotEmpty) ...[
            Text(
              'Associated Deal & Dispatch Documents',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 10),
            ..._documents.map((doc) {
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(
                      LucideIcons.fileText,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    doc.documentType,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    doc.fileName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      LucideIcons.externalLink,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    tooltip: 'View Document',
                    onPressed: () => _handleDownload(doc.fileUrl, doc.fileName),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Navigation to Deal Contract
          AppButton(
            label: 'View Linked Deal Contract',
            icon: LucideIcons.arrowUpRight,
            variant: ButtonVariant.primary,
            onPressed: () => context.push('/deals/${invoice.dealId}'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondaryLight,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSummaryLine(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? AppColors.textPrimaryLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}
