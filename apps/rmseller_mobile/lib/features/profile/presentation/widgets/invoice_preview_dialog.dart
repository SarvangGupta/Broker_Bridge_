import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/invoice_document_service.dart';
import '../profile_strings.dart';

/// Interactive modal dialog allowing inspection, zoom, retake, replacement, or removal of the invoice document.
class InvoicePreviewDialog extends StatelessWidget {
  final SelectedInvoiceDocument document;
  final VoidCallback onRetakeCamera;
  final VoidCallback onReplaceGallery;
  final VoidCallback onRemove;
  final ProfileStrings? strings;

  const InvoicePreviewDialog({
    super.key,
    required this.document,
    required this.onRetakeCamera,
    required this.onReplaceGallery,
    required this.onRemove,
    this.strings,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = document.fileName.toLowerCase().endsWith('.pdf');
    final file = File(document.localPath);
    final fileExists = file.existsSync();

    final s = strings ?? ProfileStrings.of(context);

    return Dialog(
      key: const Key('invoice_preview_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Icon(LucideIcons.fileText, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    document.fileName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  key: const Key('close_invoice_preview'),
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body Preview
          Container(
            height: 280,
            color: Colors.black12,
            child: isPdf || !fileExists
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPdf ? LucideIcons.fileText : LucideIcons.image,
                          size: 56,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          document.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${s.isHindi ? "आकार" : "Size"}: ${(document.fileSizeBytes / 1024).toStringAsFixed(1)} KB • ${document.isUploaded ? (s.isHindi ? "सर्वर पर सहेजा गया" : "Uploaded") : (s.isHindi ? "स्थानीय ड्राफ्ट" : "Local Draft")}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  )
                : InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 3.5,
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => Center(
                        child: Text(s.isHindi ? 'छवि प्रदर्शित नहीं की जा सकी' : 'Could not display image preview'),
                      ),
                    ),
                  ),
          ),

          // Upload status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: document.isUploaded ? AppColors.successBackground : Colors.grey.shade100,
            child: Row(
              children: [
                Icon(
                  document.isUploaded ? LucideIcons.checkCircle2 : LucideIcons.clock,
                  size: 14,
                  color: document.isUploaded ? AppColors.success : AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 6),
                Text(
                  document.isUploaded
                      ? (s.isHindi ? 'सर्वर पर सत्यापित रिकॉर्ड' : 'Server-Verified Persistence')
                      : (s.isHindi ? 'स्थानीय ड्राफ्ट (सेव करने पर पुष्टि होगी)' : 'Unsaved Local Draft (Confirms on save)'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: document.isUploaded ? AppColors.success : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Action Options
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('btn_retake_invoice'),
                    onPressed: () {
                      Navigator.pop(context);
                      onRetakeCamera();
                    },
                    icon: const Icon(LucideIcons.camera, size: 16),
                    label: Text(s.retryScan, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('btn_replace_invoice'),
                    onPressed: () {
                      Navigator.pop(context);
                      onReplaceGallery();
                    },
                    icon: const Icon(LucideIcons.image, size: 16),
                    label: Text(s.gallery, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('btn_remove_invoice'),
                  icon: const Icon(LucideIcons.trash2, color: AppColors.error, size: 20),
                  tooltip: s.removeDocument,
                  onPressed: () {
                    Navigator.pop(context);
                    onRemove();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
