import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'task_category.dart';
import 'task_priority.dart';
import 'task_status.dart';

/// Supported business record types that a broker task can reference.
enum LinkedRecordType {
  counterparty('Counterparty', LucideIcons.users),
  deal('Deal Contract', Icons.handshake_outlined),
  requirement('Buyer Mandate', LucideIcons.layers),
  offer('Seller Offer', LucideIcons.package),
  invoice('Commission Invoice', LucideIcons.fileSpreadsheet),
  dispute('Dispute / Exception', LucideIcons.alertTriangle);

  final String label;
  final IconData icon;

  const LinkedRecordType(this.label, this.icon);

  static LinkedRecordType fromString(String? value) {
    if (value == null) return LinkedRecordType.deal;
    switch (value.trim().toLowerCase()) {
      case 'counterparty':
      case 'contact':
      case 'company':
        return LinkedRecordType.counterparty;
      case 'deal':
      case 'contract':
        return LinkedRecordType.deal;
      case 'requirement':
      case 'mandate':
        return LinkedRecordType.requirement;
      case 'offer':
      case 'availability':
        return LinkedRecordType.offer;
      case 'invoice':
      case 'commission':
        return LinkedRecordType.invoice;
      case 'dispute':
        return LinkedRecordType.dispute;
      default:
        return LinkedRecordType.deal;
    }
  }
}

/// Metadata and real-time status of a business record linked to a task.
class TaskLinkedRecord {
  final LinkedRecordType type;
  final String id;
  final String reference;
  final String title;
  final String currentStatus;
  final bool isAccessible;
  final String? statusNotice;
  final String? route;

  const TaskLinkedRecord({
    required this.type,
    required this.id,
    required this.reference,
    required this.title,
    required this.currentStatus,
    this.isAccessible = true,
    this.statusNotice,
    this.route,
  });

  factory TaskLinkedRecord.fromJson(Map<String, dynamic> json) {
    return TaskLinkedRecord(
      type: LinkedRecordType.fromString(json['type'] as String?),
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      title: json['title'] as String? ?? '',
      currentStatus: json['currentStatus'] as String? ?? 'Active',
      isAccessible: json['isAccessible'] as bool? ?? true,
      statusNotice: json['statusNotice'] as String?,
      route: json['route'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'id': id,
      'reference': reference,
      'title': title,
      'currentStatus': currentStatus,
      'isAccessible': isAccessible,
      if (statusNotice != null) 'statusNotice': statusNotice,
      if (route != null) 'route': route,
    };
  }

  TaskLinkedRecord copyWith({
    LinkedRecordType? type,
    String? id,
    String? reference,
    String? title,
    String? currentStatus,
    bool? isAccessible,
    String? statusNotice,
    String? route,
  }) {
    return TaskLinkedRecord(
      type: type ?? this.type,
      id: id ?? this.id,
      reference: reference ?? this.reference,
      title: title ?? this.title,
      currentStatus: currentStatus ?? this.currentStatus,
      isAccessible: isAccessible ?? this.isAccessible,
      statusNotice: statusNotice ?? this.statusNotice,
      route: route ?? this.route,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskLinkedRecord &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          id == other.id;

  @override
  int get hashCode => type.hashCode ^ id.hashCode;
}

/// Audit history entry documenting a mutation to a broker task.
class TaskHistoryEntry {
  final String id;
  final String action;
  final String description;
  final String actor;
  final DateTime timestamp;

  const TaskHistoryEntry({
    required this.id,
    required this.action,
    required this.description,
    required this.actor,
    required this.timestamp,
  });

  factory TaskHistoryEntry.fromJson(Map<String, dynamic> json) {
    return TaskHistoryEntry(
      id: json['id'] as String? ?? '',
      action: json['action'] as String? ?? 'updated',
      description: json['description'] as String? ?? '',
      actor: json['actor'] as String? ?? 'Broker Desk',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'description': description,
      'actor': actor,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }
}

/// Authoritative domain model representing a broker follow-up task.
class BrokerTask {
  final String id;
  final String brokerId;
  final String? contactId;
  final String? contactName;
  final String title;
  final String description;
  final DateTime dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final TaskCategory category;
  final TaskLinkedRecord? linkedRecord;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<TaskHistoryEntry> history;

  const BrokerTask({
    required this.id,
    required this.brokerId,
    this.contactId,
    this.contactName,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.open,
    this.category = TaskCategory.general,
    this.linkedRecord,
    this.completedAt,
    required this.createdAt,
    this.updatedAt,
    this.history = const [],
  });

  /// True if the task has not been completed or cancelled and its due time is in the past.
  bool get isOverdue {
    if (status.isClosed) return false;
    return dueDate.isBefore(DateTime.now());
  }

  /// True if the task is due today in the user's local timezone.
  bool get isDueToday {
    final now = DateTime.now();
    final localDue = dueDate.toLocal();
    return localDue.year == now.year &&
        localDue.month == now.month &&
        localDue.day == now.day;
  }

  /// True if the task is due in the future (after today) and still active.
  bool get isUpcoming {
    if (status.isClosed) return false;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return dueDate.isAfter(endOfToday);
  }

  /// Human-readable localized relative time label (e.g. 'Overdue by 2 hours', 'Due today, 3:30 PM').
  String get timeLabel {
    final now = DateTime.now();
    final localDue = dueDate.toLocal();

    if (status == TaskStatus.completed) {
      if (completedAt != null) {
        return 'Completed on ${DateFormat('dd MMM, hh:mm a').format(completedAt!.toLocal())}';
      }
      return 'Completed';
    }

    if (status == TaskStatus.cancelled) {
      return 'Cancelled';
    }

    if (isOverdue) {
      final diff = now.difference(localDue);
      if (diff.inDays > 0) {
        return 'Overdue by ${diff.inDays}d (${DateFormat('dd MMM').format(localDue)})';
      } else if (diff.inHours > 0) {
        return 'Overdue by ${diff.inHours}h (${DateFormat('hh:mm a').format(localDue)})';
      } else {
        return 'Overdue (${DateFormat('hh:mm a').format(localDue)})';
      }
    }

    if (isDueToday) {
      return 'Due today, ${DateFormat('hh:mm a').format(localDue)}';
    }

    final tomorrow = now.add(const Duration(days: 1));
    if (localDue.year == tomorrow.year &&
        localDue.month == tomorrow.month &&
        localDue.day == tomorrow.day) {
      return 'Due tomorrow, ${DateFormat('hh:mm a').format(localDue)}';
    }

    return 'Due ${DateFormat('dd MMM, hh:mm a').format(localDue)}';
  }

  factory BrokerTask.fromJson(Map<String, dynamic> json) {
    // Parse title & optional embedded description
    final rawTitle = json['title'] as String? ?? '';
    String title = rawTitle;
    String description = json['description'] as String? ?? '';

    if (description.isEmpty && rawTitle.contains('\n\n')) {
      final parts = rawTitle.split('\n\n');
      title = parts[0];
      description = parts.sublist(1).join('\n\n');
    }

    // Parse dueDate with local timezone conversion
    DateTime dueDate = DateTime.now().add(const Duration(hours: 4));
    if (json['due_date'] != null) {
      dueDate = DateTime.parse(json['due_date'].toString()).toLocal();
    } else if (json['dueDate'] != null) {
      dueDate = DateTime.parse(json['dueDate'].toString()).toLocal();
    }

    // Parse createdAt
    DateTime createdAt = DateTime.now();
    if (json['created_at'] != null) {
      createdAt = DateTime.parse(json['created_at'].toString()).toLocal();
    } else if (json['createdAt'] != null) {
      createdAt = DateTime.parse(json['createdAt'].toString()).toLocal();
    }

    // Parse completedAt
    DateTime? completedAt;
    if (json['completed_at'] != null) {
      completedAt = DateTime.parse(json['completed_at'].toString()).toLocal();
    } else if (json['completedAt'] != null) {
      completedAt = DateTime.parse(json['completedAt'].toString()).toLocal();
    }

    // Parse linked record
    TaskLinkedRecord? linkedRecord;
    if (json['linked_record'] is Map<String, dynamic>) {
      linkedRecord = TaskLinkedRecord.fromJson(json['linked_record'] as Map<String, dynamic>);
    } else if (json['linkedRecord'] is Map<String, dynamic>) {
      linkedRecord = TaskLinkedRecord.fromJson(json['linkedRecord'] as Map<String, dynamic>);
    }

    // Parse history
    final historyList = (json['history'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(TaskHistoryEntry.fromJson)
        .toList();

    return BrokerTask(
      id: json['id']?.toString() ?? '',
      brokerId: json['broker_id']?.toString() ?? json['brokerId']?.toString() ?? '',
      contactId: json['contact_id']?.toString() ?? json['contactId']?.toString(),
      contactName: json['contact_name']?.toString() ?? json['contactName']?.toString() ?? json['companyName']?.toString(),
      title: title,
      description: description,
      dueDate: dueDate,
      priority: TaskPriority.fromString(json['priority'] as String?),
      status: TaskStatus.fromString(json['status'] as String?),
      category: TaskCategory.fromString(json['category'] as String?),
      linkedRecord: linkedRecord,
      completedAt: completedAt,
      createdAt: createdAt,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()).toLocal() : null,
      history: historyList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brokerId': brokerId,
      if (contactId != null) 'contactId': contactId,
      if (contactName != null) 'contactName': contactName,
      'title': title,
      'description': description,
      'dueDate': dueDate.toUtc().toIso8601String(),
      'priority': priority.toBackendString(),
      'status': status.toBackendString(),
      'category': category.toBackendString(),
      if (linkedRecord != null) 'linkedRecord': linkedRecord!.toJson(),
      if (completedAt != null) 'completedAt': completedAt!.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      'history': history.map((e) => e.toJson()).toList(),
    };
  }

  /// Maps to Postgres crm_tasks table columns for Supabase insert.
  Map<String, dynamic> toSupabaseInsert() {
    // If description exists, combine into title for PostgreSQL crm_tasks storage
    final fullTitle = description.isNotEmpty ? '$title\n\n$description' : title;
    return {
      'id': id,
      'broker_id': brokerId,
      if (contactId != null) 'contact_id': contactId,
      'title': fullTitle,
      'due_date': dueDate.toUtc().toIso8601String(),
      'priority': priority.toBackendString(),
      'status': status.toBackendString(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  /// Maps to Postgres crm_tasks table columns for Supabase update.
  Map<String, dynamic> toSupabaseUpdate() {
    final fullTitle = description.isNotEmpty ? '$title\n\n$description' : title;
    return {
      if (contactId != null) 'contact_id': contactId,
      'title': fullTitle,
      'due_date': dueDate.toUtc().toIso8601String(),
      'priority': priority.toBackendString(),
      'status': status.toBackendString(),
    };
  }

  BrokerTask copyWith({
    String? id,
    String? brokerId,
    String? contactId,
    String? contactName,
    String? title,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
    TaskStatus? status,
    TaskCategory? category,
    TaskLinkedRecord? linkedRecord,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TaskHistoryEntry>? history,
  }) {
    return BrokerTask(
      id: id ?? this.id,
      brokerId: brokerId ?? this.brokerId,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      linkedRecord: linkedRecord ?? this.linkedRecord,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? this.history,
    );
  }
}
