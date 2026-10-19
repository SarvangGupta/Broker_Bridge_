import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/task_repository.dart';
import '../../domain/task_category.dart';
import '../../domain/task_model.dart';
import '../../domain/task_priority.dart';

/// Modal bottom sheet for creating or editing a broker follow-up task.
class CreateTaskSheet extends StatefulWidget {
  final TaskRepository repository;
  final TaskLinkedRecord? preselectedLinkedRecord;
  final Function({
    required String title,
    String description,
    required DateTime dueDate,
    required TaskPriority priority,
    required TaskCategory category,
    TaskLinkedRecord? linkedRecord,
  }) onSubmit;

  const CreateTaskSheet({
    super.key,
    required this.repository,
    this.preselectedLinkedRecord,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required TaskRepository repository,
    TaskLinkedRecord? preselectedLinkedRecord,
    required Function({
      required String title,
      String description,
      required DateTime dueDate,
      required TaskPriority priority,
      required TaskCategory category,
      TaskLinkedRecord? linkedRecord,
    }) onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateTaskSheet(
        repository: repository,
        preselectedLinkedRecord: preselectedLinkedRecord,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  late DateTime _selectedDueDate;
  late TimeOfDay _selectedDueTime;
  TaskPriority _selectedPriority = TaskPriority.normal;
  TaskCategory _selectedCategory = TaskCategory.dealFollowUp;
  TaskLinkedRecord? _selectedLinkedRecord;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default to today + 3 hours or tomorrow morning
    _selectedDueDate = DateTime(now.year, now.month, now.day);
    _selectedDueTime = TimeOfDay(hour: (now.hour + 3) % 24, minute: 0);

    if (widget.preselectedLinkedRecord != null) {
      _selectedLinkedRecord = widget.preselectedLinkedRecord;
      if (_selectedLinkedRecord!.type == LinkedRecordType.deal) {
        _selectedCategory = TaskCategory.dealFollowUp;
      } else if (_selectedLinkedRecord!.type == LinkedRecordType.requirement) {
        _selectedCategory = TaskCategory.mandateMatching;
      } else if (_selectedLinkedRecord!.type == LinkedRecordType.offer) {
        _selectedCategory = TaskCategory.offerInspection;
      } else if (_selectedLinkedRecord!.type == LinkedRecordType.invoice) {
        _selectedCategory = TaskCategory.paymentCollection;
      } else if (_selectedLinkedRecord!.type == LinkedRecordType.dispute) {
        _selectedCategory = TaskCategory.disputeMediation;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate.isBefore(now) ? now : _selectedDueDate,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _selectedDueDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedDueTime,
    );

    if (picked != null) {
      setState(() => _selectedDueTime = picked);
    }
  }

  DateTime _buildFinalDueDateTime() {
    return DateTime(
      _selectedDueDate.year,
      _selectedDueDate.month,
      _selectedDueDate.day,
      _selectedDueTime.hour,
      _selectedDueTime.minute,
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final finalDue = _buildFinalDueDateTime();
      await widget.onSubmit(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        dueDate: finalDue,
        priority: _selectedPriority,
        category: _selectedCategory,
        linkedRecord: _selectedLinkedRecord,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawAvailable = widget.repository.getAvailableLinkedRecords();
    final availableRecords = {
      if (_selectedLinkedRecord != null && !rawAvailable.contains(_selectedLinkedRecord))
        _selectedLinkedRecord!,
      ...rawAvailable,
    }.toList();
    final dueDateTime = _buildFinalDueDateTime();
    final localTimeFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(dueDateTime);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Schedule Follow-up Action',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Error Notice
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.errorBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.alertCircle,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Title Input
                AppTextField(
                  label: 'Task Title / Action Required *',
                  hintText: 'e.g. Call buyer regarding final sign-off...',
                  controller: _titleController,
                  validator: (val) {
                    if (val == null || val.trim().length < 2) {
                      return 'Task title must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Description Input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Action Notes & Instructions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Add operational context, bilty check, lab notes...',
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDisabled,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Due Date & Time Selector
                const Text(
                  'Scheduled Due Date & Time',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderLight),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.calendar,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd MMM yyyy').format(_selectedDueDate),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderLight),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.clock,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedDueTime.format(context),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Local Time: $localTimeFormatted',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 14),

                // Priority Selector
                const Text(
                  'Priority Level',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: TaskPriority.values.map((priority) {
                    final isSelected = _selectedPriority == priority;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => setState(() => _selectedPriority = priority),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? priority.backgroundColor
                                  : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? priority.color
                                    : AppColors.borderLight,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                priority.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? priority.color
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Category Selector
                const Text(
                  'Task Category',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TaskCategory>(
                      value: _selectedCategory,
                      isExpanded: true,
                      items: TaskCategory.values
                          .where((c) => c != TaskCategory.all)
                          .map((cat) {
                        return DropdownMenuItem<TaskCategory>(
                          value: cat,
                          child: Row(
                            children: [
                              Icon(cat.icon, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(cat.label, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (cat) {
                        if (cat != null) setState(() => _selectedCategory = cat);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Link to Business Record (Optional)
                const Text(
                  'Link Business Record (Optional)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TaskLinkedRecord?>(
                      value: _selectedLinkedRecord != null
                          ? availableRecords.where((r) => r == _selectedLinkedRecord).firstOrNull
                          : null,
                      isExpanded: true,
                      hint: const Text(
                        'None (General Task)',
                        style: TextStyle(fontSize: 13),
                      ),
                      items: [
                        const DropdownMenuItem<TaskLinkedRecord?>(
                          value: null,
                          child: Text('None (General Task)', style: TextStyle(fontSize: 13)),
                        ),
                        ...availableRecords.map((rec) {
                          return DropdownMenuItem<TaskLinkedRecord?>(
                            value: rec,
                            child: Row(
                              children: [
                                Icon(rec.type.icon, size: 14, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${rec.reference} - ${rec.title}',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (rec) {
                        setState(() => _selectedLinkedRecord = rec);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Reminder Notice Alert Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.infoBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        LucideIcons.info,
                        size: 16,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.repository.reminderCapabilityNotice,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                AppButton(
                  label: _isSubmitting ? 'Creating Action Item...' : 'Save Follow-up Task',
                  icon: const Icon(LucideIcons.check, size: 18, color: Colors.white),
                  isLoading: _isSubmitting,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
