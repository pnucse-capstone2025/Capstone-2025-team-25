// lib/features/tasks/models/task_model.dart
import 'dart:convert';

class AppTask {
  final String uuid;
  final String name;
  final String? description;
  final String? senderDisplayName;
  String status;
  final DateTime createdAt;
  final DateTime? validUntil;
  final DateTime? startDate;
  final bool isMedication;
  final int? medicationId; // ⭐ MERGED: From the second model
  final TaskRule? rule;
  int completedOccurrences;
  int totalOccurrences;
  int totalDaysCompleted;
  bool isCompletedToday;
  final bool isSynced;

  AppTask({
    required this.uuid,
    required this.name,
    this.description,
    this.senderDisplayName,
    required this.status,
    required this.createdAt,
    this.validUntil,
    this.startDate,
    required this.isMedication,
    this.medicationId, // ⭐ MERGED
    this.rule,
    this.completedOccurrences = 0,
    this.totalOccurrences = 1,
    this.totalDaysCompleted = 0,
    this.isCompletedToday = false,
    this.isSynced = false,
  });

  /// Factory for creating an AppTask from a JSON object (e.g., API response).
  factory AppTask.fromJson(
    Map<String, dynamic> json, {
    required bool isMedication,
  }) {
    DateTime? safeParse(String? dateStr) {
      return dateStr == null ? null : DateTime.tryParse(dateStr);
    }

    final idField = isMedication ? 'med_task_uuid' : 'task_uuid';

    return AppTask(
      uuid: json[idField],
      name: json['name'],
      description: json['description'],
      senderDisplayName: json['sender_display_name'],
      status: json['status'],
      createdAt: safeParse(json['created_at']) ?? DateTime.now(),
      validUntil: safeParse(json['valid_until']),
      startDate: safeParse(json['start_date']),
      isMedication: isMedication,
      medicationId: json['medication_id'], // ⭐ MERGED
      rule: json['rule_uuid'] != null ? TaskRule.fromJson(json) : null,
      completedOccurrences: json['completedOccurrences'] ?? 0,
      totalDaysCompleted: json['totalDaysCompleted'] ?? 0,
      isSynced: true, // Data from the server is considered synced.
    );
  }

  /// Factory for creating an AppTask from a local database map.
  factory AppTask.fromDbMap(Map<String, dynamic> map) {
    return AppTask(
      uuid: map['uuid'],
      name: map['name'],
      description: map['description'],
      senderDisplayName: map['sender_display_name'],
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
      validUntil: map['valid_until'] != null
          ? DateTime.parse(map['valid_until'])
          : null,
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'])
          : null,
      isMedication: map['is_medication'] == 1,
      medicationId: map['medication_id'], // ⭐ MERGED
      rule: map['rule_json'] != null
          ? TaskRule.fromJson(jsonDecode(map['rule_json']))
          : null,
      isSynced: map['is_synced'] == 1,
    );
  }

  /// Converts an AppTask instance to a map for database storage.
  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'name': name,
      'description': description,
      'sender_display_name': senderDisplayName,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'valid_until': validUntil?.toIso8601String(),
      'start_date': startDate?.toIso8601String(),
      'is_medication': isMedication ? 1 : 0,
      'medication_id': medicationId, // ⭐ MERGED
      'rule_json': rule != null ? jsonEncode(rule!.toJson()) : null,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  /// Creates a copy of the task with some updated fields.
  AppTask copyWith({
    String? status,
    int? completedOccurrences,
    bool? isCompletedToday,
    bool? isSynced,
  }) {
    return AppTask(
      uuid: uuid,
      name: name,
      description: description,
      senderDisplayName: senderDisplayName,
      status: status ?? this.status,
      createdAt: createdAt,
      validUntil: validUntil,
      startDate: startDate,
      isMedication: isMedication,
      medicationId: medicationId,
      rule: rule,
      completedOccurrences: completedOccurrences ?? this.completedOccurrences,
      totalOccurrences: totalOccurrences,
      totalDaysCompleted: totalDaysCompleted,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

class TaskRule {
  final String? uuid;
  final String ruleType;
  final int? count;
  final String? startTime;
  final int? intervalHours;
  final int? durationDays;
  final String? extras;

  TaskRule({
    this.uuid,
    required this.ruleType,
    this.count,
    this.startTime,
    this.intervalHours,
    this.durationDays,
    this.extras,
  });

  factory TaskRule.fromJson(Map<String, dynamic> json) {
    return TaskRule(
      uuid: json['rule_uuid'],
      ruleType: json['rule_type'] ?? 'once', // Fallback for safety
      count: json['count'],
      startTime: json['start_time'],
      intervalHours: json['interval_hours'],
      durationDays: json['duration_days'],
      extras: json['extras'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rule_uuid': uuid,
      'rule_type': ruleType,
      'count': count,
      'start_time': startTime,
      'interval_hours': intervalHours,
      'duration_days': durationDays,
      'extras': extras,
    };
  }
}
