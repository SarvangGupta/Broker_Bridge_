import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/gst_filing_history.dart';
import '../controllers/gst_filing_controller.dart';

/// Modal bottom sheet displaying comprehensive GST filing history and credibility observations.
class GstFilingHistorySheet extends ConsumerStatefulWidget {
  final String gstin;
  final String? companyId;
  final String? counterpartyName;

  const GstFilingHistorySheet({
    super.key,
    required this.gstin,
    this.companyId,
    this.counterpartyName,
  });

  static void show(
    BuildContext context, {
    required String gstin,
    String? companyId,
    String? counterpartyName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GstFilingHistorySheet(
        gstin: gstin,
        companyId: companyId,
        counterpartyName: counterpartyName,
      ),
    );
  }

  @override
  ConsumerState<GstFilingHistorySheet> createState() => _GstFilingHistorySheetState();
}

class _GstFilingHistorySheetState extends ConsumerState<GstFilingHistorySheet> {
  @override
  void initState() {
    super.initState();
    // Load filing history immediately on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gstFilingControllerProvider(widget.gstin).notifier).loadFilingHistory(
            widget.gstin,
            companyId: widget.companyId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gstFilingControllerProvider(widget.gstin));
    final controller = ref.read(gstFilingControllerProvider(widget.gstin).notifier);
    final sheetHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.fileSpreadsheet, size: 20, color: Color(0xFF1E3A8A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GST Return Filing History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'GSTIN: ${widget.gstin}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Refresh Button
                if (state.isRefreshing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    key: const Key('gst_filing_refresh_button'),
                    icon: const Icon(LucideIcons.refreshCw, size: 18, color: AppColors.primaryNavy),
                    tooltip: 'Refresh from GST Portal',
                    onPressed: () {
                      controller.loadFilingHistory(
                        widget.gstin,
                        companyId: widget.companyId,
                        forceRefresh: true,
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Body Content - Expanded guarantees full available vertical space
          Expanded(
            child: _buildBody(state, controller),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(GstFilingState state, GstFilingController controller) {
    if (state.isLoading || state.status == GstFilingLoadingStatus.initial) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5),
              SizedBox(height: 16),
              Text(
                'Connecting to GST Public Returns Registry...',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              SizedBox(height: 6),
              Text(
                'Retrieving 5-year GSTR-1 and GSTR-3B records',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isError) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertCircle, size: 36, color: Color(0xFFDC2626)),
              const SizedBox(height: 10),
              const Text(
                'Could Not Retrieve GST Filing History',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
              ),
              const SizedBox(height: 6),
              Text(
                state.errorMessage ?? 'An error occurred while fetching return history.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      controller.loadFilingHistory(
                        widget.gstin,
                        companyId: widget.companyId,
                        forceRefresh: true,
                      );
                    },
                    icon: const Icon(LucideIcons.refreshCw, size: 14),
                    label: const Text('Try Again'),
                  ),
                  ElevatedButton.icon(
                    key: const Key('error_verify_official_portal_button'),
                    onPressed: () => _openOfficialGstPortal(context, widget.gstin),
                    icon: const Icon(LucideIcons.externalLink, size: 14),
                    label: const Text('Verify on Official Portal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                key: const Key('error_record_portal_verification_btn'),
                onPressed: () => _showRecordPortalVerificationDialog(context, widget.gstin, controller),
                icon: const Icon(LucideIcons.shieldCheck, size: 14),
                label: const Text('Record Portal Verification Manually'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isEmpty || state.snapshot == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.fileX, size: 36, color: AppColors.textSecondary),
              const SizedBox(height: 10),
              const Text(
                'No GST filing history available for this GSTIN.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'No return filing records could be located in the public registry for GSTIN ${widget.gstin}. You can verify filing details directly on the Official GST Portal.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    key: const Key('empty_verify_official_portal_button'),
                    onPressed: () => _openOfficialGstPortal(context, widget.gstin),
                    icon: const Icon(LucideIcons.externalLink, size: 14),
                    label: const Text('Verify on Official GST Portal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                key: const Key('empty_record_portal_verification_btn'),
                onPressed: () => _showRecordPortalVerificationDialog(context, widget.gstin, controller),
                icon: const Icon(LucideIcons.shieldCheck, size: 14),
                label: const Text('Record Portal Verification Manually'),
              ),
            ],
          ),
        ),
      );
    }

    final snapshot = state.snapshot!;
    final taxpayer = snapshot.taxpayer;
    final summary = snapshot.summary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Taxpayer Profile Banner
          _buildTaxpayerBanner(taxpayer, snapshot),
          const SizedBox(height: 14),

          // 2. Business Credibility Observations Card
          _buildCredibilityCard(summary),
          const SizedBox(height: 18),

          // 3. Financial Year Filter Tabs
          _buildFinancialYearSelector(snapshot.availableFinancialYears, state.selectedFinancialYear, controller),
          const SizedBox(height: 12),

          // 4. Return Filing Records Table / List
          _buildReturnsList(state.displayedFilings),
          const SizedBox(height: 20),

          // 5. Source & Fiduciary Disclaimer
          _buildFooterDisclaimer(snapshot),
        ],
      ),
    );
  }

  Widget _buildTaxpayerBanner(GstTaxpayerDetails taxpayer, GstFilingSnapshot snapshot) {
    Color statusColor;
    Color statusBg;
    if (taxpayer.isActive) {
      statusColor = const Color(0xFF15803D);
      statusBg = const Color(0xFFDCFCE7);
    } else if (taxpayer.isCancelled) {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEE2E2);
    } else {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFEF3C7);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  taxpayer.tradeName?.isNotEmpty == true
                      ? taxpayer.tradeName!
                      : taxpayer.legalName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  taxpayer.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (taxpayer.legalName != taxpayer.tradeName && taxpayer.tradeName?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              'Legal: ${taxpayer.legalName}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(LucideIcons.mapPin, size: 13, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  taxpayer.principalAddress ?? (taxpayer.state ?? 'Address not specified'),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(LucideIcons.calendar, size: 13, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Registered: ${taxpayer.registrationDate ?? "N/A"}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              if (taxpayer.cancellationDate != null) ...[
                const SizedBox(width: 8),
                Text(
                  '• Cancelled: ${taxpayer.cancellationDate}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                ),
              ],
              const Spacer(),
              Text(
                taxpayer.filingFrequency,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
              ),
            ],
          ),
          const Divider(height: 16, color: AppColors.borderLight),
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Last fetched: ${snapshot.formattedRetrievedAt} ${snapshot.isCached ? "(Cached)" : "(Live)"}',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: snapshot.dataSource.contains('Official')
                      ? const Color(0xFFEFF6FF)
                      : (snapshot.dataSource.contains('Jamku')
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  snapshot.dataSource,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: snapshot.dataSource.contains('Official')
                        ? const Color(0xFF1D4ED8)
                        : (snapshot.dataSource.contains('Jamku')
                            ? const Color(0xFF047857)
                            : const Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('banner_open_official_portal_button'),
                  onPressed: () => _openOfficialGstPortal(context, widget.gstin),
                  icon: const Icon(LucideIcons.externalLink, size: 12, color: Color(0xFF1E3A8A)),
                  label: const Text(
                    'Official Portal (gst.gov.in)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    backgroundColor: const Color(0xFFEFF6FF),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('banner_record_portal_verification_button'),
                onPressed: () {
                  final ctrl = ref.read(gstFilingControllerProvider(widget.gstin).notifier);
                  _showRecordPortalVerificationDialog(context, widget.gstin, ctrl);
                },
                icon: const Icon(LucideIcons.shieldCheck, size: 12, color: AppColors.textSecondary),
                label: const Text(
                  'Record Note',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openOfficialGstPortal(BuildContext context, String gstin) async {
    await Clipboard.setData(ClipboardData(text: gstin));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GSTIN $gstin copied to clipboard! Opening Official GST Portal...'),
          duration: const Duration(seconds: 4),
          backgroundColor: const Color(0xFF1E3A8A),
        ),
      );
    }

    final uri = Uri.parse('https://services.gst.gov.in/services/searchtp');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch official GST portal: $e');
    }
  }

  void _showRecordPortalVerificationDialog(
    BuildContext context,
    String gstin,
    GstFilingController controller,
  ) {
    String observedStatus = 'Active';
    final notesController = TextEditingController();
    final filingController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(LucideIcons.shieldCheck, color: Color(0xFF1E3A8A), size: 20),
              SizedBox(width: 8),
              Text(
                'Record Portal Verification',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record filing observations after solving the official CAPTCHA on services.gst.gov.in.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Registration Status on Portal',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: observedStatus,
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                    DropdownMenuItem(value: 'Suspended', child: Text('Suspended')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => observedStatus = val);
                    }
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Latest Return Period Observed',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: filingController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. GSTR-3B filed for Sep 2026',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Broker Review Notes',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Verified trade name matches GST certificate',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('save_manual_portal_verification_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                controller.recordManualPortalVerification(
                  targetGstin: gstin,
                  companyId: widget.companyId,
                  observedStatus: observedStatus,
                  latestFilingSummary: filingController.text.trim(),
                  brokerNotes: notesController.text.trim(),
                );
              },
              child: const Text('Save Verification'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredibilityCard(GstCredibilitySummary summary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.shieldCheck, size: 16, color: Color(0xFF1E3A8A)),
              SizedBox(width: 8),
              Text(
                'Credibility Observations (Factual Data)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Returns Filed',
                  value: summary.totalConfirmedFiled.toString(),
                  icon: LucideIcons.checkCircle2,
                  iconColor: const Color(0xFF15803D),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Overdue Returns',
                  value: summary.totalConfirmedOverdue.toString(),
                  icon: LucideIcons.alertTriangle,
                  iconColor: summary.totalConfirmedOverdue > 0 ? const Color(0xFFDC2626) : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Latest Filing',
                  value: summary.latestFilingDate ?? 'None',
                  icon: LucideIcons.calendarCheck,
                  iconColor: const Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildObservationRow('Filing Schedule', summary.filingFrequency),
          _buildObservationRow('Historical Coverage', summary.historicalCoverage),
          if (summary.delayObservations.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Observed Filing Delays (Public Record Dates):',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
            ),
            const SizedBox(height: 4),
            ...summary.delayObservations.take(3).map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Color(0xFF92400E))),
                        Expanded(
                          child: Text(d, style: const TextStyle(fontSize: 10.5, color: Color(0xFF92400E))),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          if (summary.dataLimitationNotice != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                summary.dataLimitationNotice!,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF1E40AF)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildObservationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialYearSelector(
    List<String> years,
    String? selectedYear,
    GstFilingController controller,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...years.map((fy) {
            final isSelected = selectedYear == fy;
            final isCurrent = fy == '2026-27';
            final label = isCurrent ? 'FY $fy (YTD)' : 'FY $fy';

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
                selectedColor: const Color(0xFF1E3A8A),
                backgroundColor: const Color(0xFFF1F5F9),
                onSelected: (selected) {
                  if (selected) controller.selectFinancialYear(fy);
                },
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('All Years'),
              selected: selectedYear == 'All',
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: selectedYear == 'All' ? FontWeight.w700 : FontWeight.w500,
                color: selectedYear == 'All' ? Colors.white : AppColors.textPrimary,
              ),
              selectedColor: const Color(0xFF1E3A8A),
              backgroundColor: const Color(0xFFF1F5F9),
              onSelected: (selected) {
                if (selected) controller.selectFinancialYear('All');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnsList(List<TaxPeriodFiling> filings) {
    if (filings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: const Text(
          'No filings recorded for the selected financial year.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Tax Period',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'GSTR-1 / IFF',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'GSTR-3B',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Table Rows
        ...filings.map((f) => _buildFilingRow(f)),
      ],
    );
  }

  Widget _buildFilingRow(TaxPeriodFiling f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Label
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.taxPeriod,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (f.isQuarterly)
                  const Text(
                    'QRMP Scheme',
                    style: TextStyle(fontSize: 9.5, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),

          // GSTR-1 Status & Date
          Expanded(
            flex: 4,
            child: _buildStatusColumn(
              status: f.gstr1Status,
              filingDate: f.gstr1FilingDate,
              dueDate: f.gstr1DueDate,
            ),
          ),

          // GSTR-3B Status & Date
          Expanded(
            flex: 4,
            child: _buildStatusColumn(
              status: f.gstr3bStatus,
              filingDate: f.gstr3bFilingDate,
              dueDate: f.gstr3bDueDate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusColumn({
    required String status,
    String? filingDate,
    String? dueDate,
  }) {
    Color badgeColor;
    Color badgeBg;

    if (GstReturnStatus.isFiled(status)) {
      badgeColor = const Color(0xFF15803D);
      badgeBg = const Color(0xFFDCFCE7);
    } else if (GstReturnStatus.isNotFiled(status)) {
      badgeColor = const Color(0xFFDC2626);
      badgeBg = const Color(0xFFFEE2E2);
    } else if (GstReturnStatus.isNotDue(status)) {
      badgeColor = const Color(0xFF1D4ED8);
      badgeBg = const Color(0xFFDBEAFE);
    } else {
      badgeColor = Colors.grey.shade700;
      badgeBg = Colors.grey.shade200;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ),
        if (filingDate != null && filingDate.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            filingDate,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _buildFooterDisclaimer(GstFilingSnapshot snapshot) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.info, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Data Source: ${snapshot.dataSource}',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Factual tax return filing records retrieved for fiduciary review. This record does not constitute an arbitrary credit score, and quarterly filers under QRMP are accurately evaluated without assuming unfiled monthly returns.',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3),
          ),
        ],
      ),
    );
  }
}

