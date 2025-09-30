// lib/models/task_request_model.dart
import 'dart:convert';

class TaskRequest {
  final String requestUuid;
  final String partnerUuid; // Can be sender or assignee
  final String partnerDisplayName;
  final String taskType;
  final Map<String, dynamic> taskData;
  final String status;
  final DateTime createdAt;

  TaskRequest({
    required this.requestUuid,
    required this.partnerUuid,
    required this.partnerDisplayName,
    required this.taskType,
    required this.taskData,
    required this.status,
    required this.createdAt,
  });

  // For requests you have RECEIVED
  factory TaskRequest.fromReceivedJson(Map<String, dynamic> json) {
    return TaskRequest(
      requestUuid: json['request_uuid'],
      partnerUuid: json['sender_uuid'],
      partnerDisplayName: json['sender_display_name'],
      taskType: json['task_type'],
      taskData: jsonDecode(json['task_data']),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  // For requests you have SENT
  factory TaskRequest.fromSentJson(Map<String, dynamic> json) {
    return TaskRequest(
      requestUuid: json['request_uuid'],
      partnerUuid: json['assignee_uuid'],
      partnerDisplayName: json['assignee_display_name'],
      taskType: json['task_type'],
      taskData: jsonDecode(json['task_data']),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get taskName => taskData['name'] ?? 'Untitled Task';
  String get taskDescription => taskData['description'] ?? 'No description.';
}
