import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../requirements/data/requirements_repository.dart';
import '../../requirements/domain/master_requirement_data.dart';
import '../../requirements/presentation/commodity_picker_sheet.dart';

/// Opens the details sheet for one Product Master raw material.
Future<void> showRawMaterialDetailsSheet({
  required BuildContext context,
  required MasterCommodity material,
  required RequirementsRepository repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) =>
        RawMaterialDetailsSheet(material: material, repository: repository),
  );
}

/// Shows a raw material's master record and grades exactly as stored, and
/// starts a requirement with only the material prefilled.
class RawMaterialDetailsSheet extends StatefulWidget {
  final MasterCommodity material;
  final RequirementsRepository repository;

  const RawMaterialDetailsSheet({
    super.key,
    required this.material,
    required this.repository,
  });

  /// `protein_min` → `Protein (min)`; unknown keys are shown word-for-word.
  static String parameterLabel(String key) {
    final parts = key.split('_').where((p) => p.isNotEmpty).toList();
    String? bound;
    if (parts.length > 1 && (parts.last == 'min' || parts.last == 'max')) {
      bound = parts.removeLast();
    }
    final words = parts.join(' ');
    final label = words.isEmpty
        ? key
        : words[0].toUpperCase() + words.substring(1);
    return bound == null ? label : '$label ($bound)';
  }

  @override
  State<RawMaterialDetailsSheet> createState() =>
      _RawMaterialDetailsSheetState();
}

class _RawMaterialDetailsSheetState extends State<RawMaterialDetailsSheet> {
  late Future<List<MasterGrade>> _grades;

  @override
  void initState() {
    super.initState();
    _grades = widget.repository.getMasterGrades(widget.material.id);
  }

  void _postRequirement() {
    final name = widget.material.name;
    Navigator.of(context).pop();
    context.push(
      '/requirements/new',
      extra: {'commodity': name, 'blankCommercialTerms': true},
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.material;
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                m.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              CategoryLabel(categoryName: m.categoryName),
              const SizedBox(height: 2),
              Text(
                m.code.isNotEmpty
                    ? 'Product code: ${m.code}'
                    : 'Product code: not recorded',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMutedLight,
                ),
              ),
              const SizedBox(height: 16),
              _section(
                icon: LucideIcons.flaskConical,
                title: 'Nutrient composition',
                child: const Text(
                  'Not recorded in the product master. Ask the supplier for a lab '
                  'report before using this material in a ration.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _section(
                icon: LucideIcons.badgeCheck,
                title: 'Grade Specifications',
                child: FutureBuilder<List<MasterGrade>>(
                  future: _grades,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Text(
                        'Loading grades...',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return const Text(
                        'Could not load grades for this material.',
                        style: TextStyle(fontSize: 13, color: AppColors.error),
                      );
                    }
                    final grades = snap.data ?? const [];
                    if (grades.isEmpty) {
                      return const Text(
                        'No grade has been approved for this material yet.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [for (final g in grades) _gradeRow(g)],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                key: const Key('nutrition-post-requirement'),
                label: 'Post Requirement',
                icon: LucideIcons.clipboardList,
                onPressed: _postRequirement,
              ),
              const SizedBox(height: 6),
              Text(
                'Only ${m.name} is prefilled. You enter quantity, price, '
                'delivery and payment terms.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMutedLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gradeRow(MasterGrade g) {
    final params = g.parameters ?? const {};
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            g.gradeName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          if (params.isEmpty)
            const Text(
              'No limits recorded for this grade.',
              style: TextStyle(fontSize: 12, color: AppColors.textMutedLight),
            ),
          for (final e in params.entries)
            Text(
              '${RawMaterialDetailsSheet.parameterLabel(e.key)}: ${e.value}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMutedLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
