import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';

/// Collapsible detail section: tinted icon, title, one-line summary and a
/// chevron. Starts collapsed each time its page opens; the expanded state is
/// local, so sections never affect one another.
class DetailAccordionCard extends StatefulWidget {
  final String sectionKey;
  final IconData icon;
  final Color tint;
  final String title;
  final String summary;

  /// Shown on the right of the header (e.g. "0% Fulfilled").
  final String? trailingLabel;
  final Widget child;

  const DetailAccordionCard({
    super.key,
    required this.sectionKey,
    required this.icon,
    required this.tint,
    required this.title,
    required this.summary,
    this.trailingLabel,
    required this.child,
  });

  @override
  State<DetailAccordionCard> createState() => _DetailAccordionCardState();
}

class _DetailAccordionCardState extends State<DetailAccordionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: _expanded,
              label: widget.title,
              child: InkWell(
                key: ValueKey('req_section_${widget.sectionKey}'),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  color: tint.withValues(alpha: 0.06),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: tint.withValues(alpha: 0.14),
                        child: Icon(widget.icon, size: 19, color: tint),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            if (!_expanded) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.summary,
                                key: ValueKey('req_section_summary_${widget.sectionKey}'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondaryLight),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.trailingLabel != null && _expanded) ...[
                        Text(
                          widget.trailingLabel!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(width: 6),
                      ],
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(LucideIcons.chevronDown, size: 20, color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_expanded)
              Padding(
                key: ValueKey('req_section_body_${widget.sectionKey}'),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: widget.child,
              ),
          ],
        ),
      ),
    );
  }
}
