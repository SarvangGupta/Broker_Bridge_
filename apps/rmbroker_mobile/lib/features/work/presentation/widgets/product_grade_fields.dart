import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/trade_master_data.dart';
import 'commodity_picker_field.dart';

String noGradeMessage(String productName) =>
    'No grade is defined for $productName in the Product Master yet. '
    'It cannot be submitted until a grade is added.';

/// Product picker plus a grade dropdown that only ever lists the selected product's own grades.
class ProductGradeFields extends StatelessWidget {
  final TradeMasterData master;
  final String? commodityId;
  final String? gradeId;
  final ValueChanged<MasterDropdownItem> onCommodityChanged;
  final ValueChanged<String?> onGradeChanged;
  final VoidCallback onRetry;

  const ProductGradeFields({
    super.key,
    required this.master,
    required this.commodityId,
    required this.gradeId,
    required this.onCommodityChanged,
    required this.onGradeChanged,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (master.commodities.isEmpty) {
      return Container(
        key: const Key('catalogue-unavailable'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.errorBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.alertCircle, size: 16, color: AppColors.error),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Product catalogue could not be loaded.',
                style: TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    final selected = master.commodityById(commodityId);
    final grades = master.gradesFor(commodityId);
    final validGrade = grades.any((g) => g.id == gradeId) ? gradeId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CommodityPickerField(
          commodities: master.commodities,
          selected: selected,
          onSelected: onCommodityChanged,
        ),
        const SizedBox(height: 12),
        if (selected != null && grades.isEmpty)
          Container(
            key: const Key('no-grade-notice'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.errorBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              noGradeMessage(selected.name),
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          )
        else
          DropdownButtonFormField<String>(
            // Rebuild per product so a grade from another product can never stay selected.
            key: ValueKey('grade-dropdown-${selected?.id}'),
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Quality Grade *',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            initialValue: validGrade,
            hint: Text(selected == null ? 'Select a product first' : 'Select grade'),
            items: grades
                .map((g) => DropdownMenuItem<String>(value: g.id, child: Text(g.name)))
                .toList(),
            onChanged: selected == null ? null : onGradeChanged,
          ),
      ],
    );
  }
}
