import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rmbroker_mobile/app/theme/app_colors.dart';
import 'voice_search_dialog.dart';

/// Top search input bar with debouncing indicator, clear button, and voice search action.
class SearchInputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;
  final bool isDebouncing;
  final bool isLoading;
  final ValueChanged<String> onVoiceQuerySelected;

  const SearchInputBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.isDebouncing = false,
    this.isLoading = false,
    required this.onVoiceQuerySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDebouncing || isLoading)
              ? AppColors.primary
              : AppColors.borderLight,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          // Search Icon or Activity Spinner
          if (isDebouncing || isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            const Icon(
              LucideIcons.search,
              size: 20,
              color: AppColors.textSecondaryLight,
            ),
          const SizedBox(width: 10),

          // Search Text Field
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted(),
              textInputAction: TextInputAction.search,
              autofocus: false,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryLight,
              ),
              decoration: const InputDecoration(
                hintText: 'Search buyers, sellers, commodities, deals...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textDisabled,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
            ),
          ),

          // Clear button if text is present
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.x, size: 18),
              tooltip: 'Clear search',
              color: AppColors.textSecondaryLight,
              onPressed: () {
                controller.clear();
                onClear();
              },
            ),

          // Microphone button for voice search
          IconButton(
            icon: const Icon(LucideIcons.mic, size: 19),
            tooltip: 'Voice Search',
            color: AppColors.primary,
            onPressed: () {
              VoiceSearchDialog.show(
                context,
                onQuerySelected: (recognized) {
                  controller.text = recognized;
                  controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: recognized.length),
                  );
                  onVoiceQuerySelected(recognized);
                },
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
