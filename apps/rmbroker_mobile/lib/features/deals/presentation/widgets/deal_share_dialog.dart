import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../directory/domain/cheque_leaf_data.dart';
import '../../data/deal_repository.dart';
import '../../domain/deal_model.dart';
import '../../domain/deal_share_model.dart';
import '../controllers/deals_controller.dart';

/// Modal dialog allowing the broker to review and securely share an authoritative
/// Deal/Order Summary and optional seller cheque leaf with the buyer upon confirmation.
class DealShareDialog extends ConsumerStatefulWidget {
  final DealDetailItem detail;
  final ChequeLeafData? initialSellerBank;

  const DealShareDialog({
    super.key,
    required this.detail,
    this.initialSellerBank,
  });

  static Future<void> show(
    BuildContext context, {
    required DealDetailItem detail,
    ChequeLeafData? sellerBank,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => DealShareDialog(
        detail: detail,
        initialSellerBank: sellerBank,
      ),
    );
  }

  @override
  ConsumerState<DealShareDialog> createState() => _DealShareDialogState();
}

class _DealShareDialogState extends ConsumerState<DealShareDialog> {
  bool _authorizeChequeShare = false;
  bool _isSharing = false;
  ChequeLeafData? _sellerBank;
  bool _isLoadingBank = false;

  @override
  void initState() {
    super.initState();
    _sellerBank = widget.initialSellerBank;
    if (_sellerBank == null) {
      _fetchSellerBank();
    }
  }

  Future<void> _fetchSellerBank() async {
    setState(() => _isLoadingBank = true);
    try {
      final repo = ref.read(dealRepositoryProvider);
      final bank = await repo.getSellerBankDetails(widget.detail.deal.sellerCompanyId);
      if (mounted) {
        setState(() {
          _sellerBank = bank;
          _isLoadingBank = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBank = false);
    }
  }

  Future<void> _executeShare() async {
    setState(() => _isSharing = true);
    final summary = DealOrderSummary.fromDealDetail(
      widget.detail,
      sellerBank: _sellerBank,
      authorizeChequeSharing: _authorizeChequeShare,
    );

    try {
      final repo = ref.read(dealRepositoryProvider);
      await repo.logDealDocumentShare(
        dealId: widget.detail.deal.id,
        recipientCompanyId: widget.detail.deal.buyerCompanyId,
        documentType: _authorizeChequeShare ? 'all' : 'deal_summary',
        sharedPayload: summary.toJson(),
        documentRef: _authorizeChequeShare ? _sellerBank?.documentPath : null,
      );

      if (mounted) {
        setState(() => _isSharing = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _authorizeChequeShare
                  ? 'Deal summary and cheque leaf securely shared with ${widget.detail.deal.buyerCompanyName}.'
                  : 'Deal summary securely shared with ${widget.detail.deal.buyerCompanyName}.',
            ),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSharing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.detail.deal;
    final detail = widget.detail;
    final cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final summary = DealOrderSummary.fromDealDetail(
      detail,
      sellerBank: _sellerBank,
      authorizeChequeSharing: _authorizeChequeShare,
    );
    final hasChequeLeaf = _sellerBank != null &&
        (_sellerBank!.documentPath != null ||
            (_sellerBank!.accountNumber != null && _sellerBank!.accountNumber!.isNotEmpty));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.share2, size: 20, color: AppColors.primaryNavy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Share Deal & Banking Summary',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Order summary for ${deal.ref}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderLight),

            // Scrollable Summary Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trade Parties Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          _buildPartyRow('Buyer (Recipient)', deal.buyerCompanyName, LucideIcons.shoppingBag),
                          const Divider(height: 16, color: AppColors.borderLight),
                          _buildPartyRow('Seller', deal.sellerCompanyName, LucideIcons.store),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Order & Pricing Details
                    const Text(
                      'Agreed Commercial Terms',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          _buildTermRow('Commodity', '${deal.commodityName} ${deal.gradeName ?? ""}'),
                          _buildTermRow('Agreed Quantity', '${deal.agreedQuantity} ${deal.unitSymbol}'),
                          _buildTermRow('Agreed Rate', '${cur.format(deal.agreedPrice)} / ${deal.unitSymbol}'),
                          _buildTermRow('Total Valuation', cur.format(deal.totalValuation)),
                          const Divider(height: 16, color: AppColors.borderLight),
                          _buildTermRow('Price Basis', deal.priceBasis),
                          _buildTermRow('Delivery Location', deal.deliveryLocation ?? 'FOR Mandi Warehouse'),
                          _buildTermRow('Delivery Terms', detail.deliveryTerms),
                          _buildTermRow('Payment Terms', detail.paymentTerms),
                          _buildTermRow('Packaging', detail.packagingType),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Seller Banking Section
                    const Text(
                      'Seller Bank Details & Cheque Leaf',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),

                    if (_isLoadingBank) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ] else if (hasChequeLeaf) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.landmark, size: 16, color: Color(0xFF15803D)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _sellerBank?.bankName ?? 'Seller Bank Account',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Cheque Leaf Supported',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildBankRow('Account Holder', _sellerBank?.accountHolderName ?? deal.sellerCompanyName),
                            _buildBankRow('Account No', _sellerBank?.maskedAccountNumber ?? '•••• •••• ****'),
                            _buildBankRow('IFSC Code', _sellerBank?.ifsc ?? 'N/A'),
                            if (_sellerBank?.branch != null) _buildBankRow('Branch', _sellerBank!.branch!),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Cheque Leaf Provided — Broker Recorded. (Not government/bank verified).',
                                style: TextStyle(fontSize: 10.5, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Authorization Checkbox
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    key: const Key('authorize_cheque_share_checkbox'),
                                    value: _authorizeChequeShare,
                                    activeColor: const Color(0xFF15803D),
                                    onChanged: (val) => setState(() => _authorizeChequeShare = val ?? false),
                                  ),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(height: 6),
                                        Text(
                                          'Authorize Cheque Leaf Sharing',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'I explicitly authorize sharing the seller\'s recorded bank details and cheque leaf with the confirmed buyer for settlement.',
                                          style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // No Cheque Leaf Available
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(LucideIcons.alertCircle, size: 16, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No cheque-leaf supported bank details available for this seller. Only commercial deal terms will be shared with the buyer.',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Preview formatted shareable text
                    ExpansionTile(
                      title: const Text(
                        'Preview Complete Message',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SelectableText(
                            summary.toShareableText(includeAuthorizedBanking: _authorizeChequeShare),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFFF1F5F9),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: AppColors.borderLight),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(color: AppColors.borderLight),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      key: const Key('confirm_share_deal_button'),
                      onPressed: _isSharing ? null : _executeShare,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(LucideIcons.send, size: 16),
                      label: Text(
                        _isSharing ? 'Recording Share...' : 'Share with Buyer',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        backgroundColor: AppColors.primaryNavy,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyRow(String label, String name, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        const Spacer(),
        Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildTermRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534))),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF14532D))),
        ],
      ),
    );
  }
}
