import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/saved_location_model.dart';

const _tileColor = Color(0xFFECFDF5);
const _badgeColor = Color(0xFFD1FAE5);
const _badgeText = Color(0xFF065F46);
const _fieldFill = Color(0xFFF8FAFC);

InputDecoration tradeInputDecoration({String? hint, Widget? prefixIcon}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMutedLight),
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: _fieldFill,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: border(AppColors.borderLight),
    enabledBorder: border(AppColors.borderLight),
    focusedBorder: border(AppColors.primary),
  );
}

class TradeFormHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const TradeFormHeader({super.key, required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(LucideIcons.arrowLeft, size: 22, color: AppColors.textPrimaryLight),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: _tileColor, shape: BoxShape.circle),
          child: Icon(icon, size: 22, color: AppColors.primary),
        ),
      ],
    );
  }
}

/// Numbered, bordered form section.
class TradeFormSection extends StatelessWidget {
  final String number;
  final String title;
  final List<Widget> children;

  const TradeFormSection({super.key, required this.number, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEF2F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: _badgeColor, shape: BoxShape.circle),
                child: Text(
                  number,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _badgeText),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimaryLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// Icon tile on the left, one or more fields on the right.
class TradeFormRow extends StatelessWidget {
  final IconData icon;
  final Widget child;

  /// Aligns the tile with the field under a label; 0 when the child has its own header.
  final double topInset;

  const TradeFormRow({super.key, required this.icon, required this.child, this.topInset = 22});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            margin: EdgeInsets.only(top: topInset, right: 10),
            decoration: BoxDecoration(color: _tileColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Field with its label above, and a red star when required.
class TradeField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool required;

  const TradeField({super.key, required this.label, required this.child, this.required = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

class TradeDateField extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;

  const TradeDateField({super.key, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = date;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: tradeInputDecoration(),
        child: Row(
          children: [
            const Icon(LucideIcons.calendar, size: 16, color: AppColors.textSecondaryLight),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                d == null
                    ? 'Select date'
                    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: d == null ? FontWeight.w400 : FontWeight.w600,
                  color: d == null ? AppColors.textMutedLight : AppColors.textPrimaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header of a location field: label plus the "from saved locations" badge.
class TradeLocationLabel extends StatelessWidget {
  final String label;
  final String badge;

  const TradeLocationLabel({super.key, required this.label, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: const [TextSpan(text: ' *', style: TextStyle(color: AppColors.error))],
          ),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: _tileColor, borderRadius: BorderRadius.circular(10)),
          child: Text(badge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _badgeText)),
        ),
      ],
    );
  }
}

/// Compact card for the saved location in use, with a way to pick another.
class TradeSavedLocationCard extends StatelessWidget {
  final SavedLocation location;
  final String selectedText;
  final Key changeKey;
  final VoidCallback onChange;

  const TradeSavedLocationCard({
    super.key,
    required this.location,
    required this.selectedText,
    required this.changeKey,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _fieldFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.warehouse, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
                    ),
                    const SizedBox(height: 2),
                    Text(location.address, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                key: changeKey,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(LucideIcons.arrowLeftRight, size: 14),
                label: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: onChange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: _tileColor, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              const Icon(LucideIcons.checkCircle2, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(selectedText, style: const TextStyle(fontSize: 11, color: _badgeText))),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown when a counterparty has no saved location, or it could not be loaded.
class TradeNoLocationCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onAdd;

  const TradeNoLocationCard({super.key, required this.message, this.onRetry, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _fieldFill, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderLight)),
      child: Row(
        children: [
          const Icon(LucideIcons.mapPinOff, size: 18, color: AppColors.textMutedLight),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight))),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
          if (onAdd != null) TextButton(key: const Key('no_location_add_btn'), onPressed: onAdd, child: const Text('Add')),
        ],
      ),
    );
  }
}

/// Opens the selected counterparty's name and location summary.
class TradeViewButton extends StatelessWidget {
  final VoidCallback onPressed;

  const TradeViewButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, left: 8),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 44)),
        icon: const Icon(LucideIcons.user, size: 15),
        label: const Text('View', style: TextStyle(fontSize: 12)),
        onPressed: onPressed,
      ),
    );
  }
}

Future<void> showTradeCounterpartySummary(BuildContext context, String name, SavedLocation? location) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: Text(location == null ? 'No saved location selected.' : location.locationSnapshot),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ),
  );
}

class TradeNotesTile extends StatefulWidget {
  final TextEditingController controller;
  final String hint;

  const TradeNotesTile({super.key, required this.controller, required this.hint});

  @override
  State<TradeNotesTile> createState() => _TradeNotesTileState();
}

class _TradeNotesTileState extends State<TradeNotesTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _fieldFill,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          ListTile(
            key: const Key('trade-notes-toggle'),
            dense: true,
            leading: const Icon(LucideIcons.fileText, size: 18, color: AppColors.textSecondaryLight),
            title: const Text('Add notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            trailing: Icon(_expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: TextField(
                key: const Key('trade-notes-field'),
                controller: widget.controller,
                maxLines: 2,
                decoration: tradeInputDecoration(hint: widget.hint),
              ),
            ),
        ],
      ),
    );
  }
}

class TradeErrorBanner extends StatelessWidget {
  final String message;

  const TradeErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.error))),
        ],
      ),
    );
  }
}

class TradeLoadingRow extends StatelessWidget {
  final String message;

  const TradeLoadingRow({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Flexible(child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight))),
        ],
      ),
    );
  }
}

class TradeSaveButton extends StatelessWidget {
  final Key buttonKey;
  final String label;
  final String savingLabel;
  final bool isSaving;
  final VoidCallback onPressed;

  const TradeSaveButton({
    super.key,
    required this.buttonKey,
    required this.label,
    required this.savingLabel,
    required this.isSaving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        key: buttonKey,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        icon: isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(LucideIcons.check, size: 18),
        label: Text(isSaving ? savingLabel : label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        onPressed: isSaving ? null : onPressed,
      ),
    );
  }
}
