import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmbroker_mobile/app/theme/app_colors.dart';

/// Modal dialog providing Voice-to-Text interaction and transparent manual fallback.
class VoiceSearchDialog extends StatefulWidget {
  final ValueChanged<String> onQuerySelected;

  const VoiceSearchDialog({super.key, required this.onQuerySelected});

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onQuerySelected,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          VoiceSearchDialog(onQuerySelected: onQuerySelected),
    );
  }

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog> {
  final List<String> _sampleQueries = const [
    'Soyabean 50 MT',
    'Mustard Seed Jaipur',
    'Bikaner Buyer',
    'Kota Milling Wheat',
    'Yellow Peas Indore',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surfaceLight,
      contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Microphone Visual with pulse styling
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.mic,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Voice-to-Text Search',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariantLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.info,
                  size: 16,
                  color: AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Microphone speech-to-text recognition service is deferred to upcoming platform milestone. Fast manual typing is active.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Suggested quick voice voice-queries to test query review & selection
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sample Broker Voice Queries:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sampleQueries.map((term) {
              return ActionChip(
                avatar: const Icon(LucideIcons.sparkles, size: 13, color: AppColors.primary),
                label: Text(
                  term,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                backgroundColor: AppColors.backgroundLight,
                side: BorderSide(color: AppColors.borderLight),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onQuerySelected(term);
                },
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.keyboard, size: 16),
          label: const Text('Manual Typing'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
