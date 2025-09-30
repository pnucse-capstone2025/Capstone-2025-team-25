// lib/services/task_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import '../utils/constants.dart';
import 'notification_service.dart';

class TaskService {
  final NotificationService _notificationService = NotificationService();
  final String _apiUrl = '$kBaseUrl/api';

  Future<List<AppTask>> fetchTasks(String userUuid) async {
    try {
      final taskResponse = await http.get(
        Uri.parse('$_apiUrl/tasks?user_uuid=$userUuid'),
      );
      final medResponse = await http.get(
        Uri.parse('$_apiUrl/medications?user_uuid=$userUuid'),
      );

      if (taskResponse.statusCode == 200 && medResponse.statusCode == 200) {
        final List<dynamic> taskData = jsonDecode(taskResponse.body)['data'];
        final List<dynamic> medData = jsonDecode(medResponse.body)['data'];

        List<AppTask> tasks = taskData
            .map((json) => AppTask.fromJson(json, isMedication: false))
            .toList();
        List<AppTask> medTasks = medData
            .map((json) => AppTask.fromJson(json, isMedication: true))
            .toList();

        return [...tasks, ...medTasks];
      } else {
        throw Exception('Failed to load tasks from the server.');
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      rethrow; 
    }
  }

  Future<bool> updateTaskStatus(
    String taskUuid,
    String newStatus,
    String actorUuid,
    bool isMedication,
  ) async {
    final endpoint = isMedication
        ? '$_apiUrl/medications/$taskUuid/status'
        : '$_apiUrl/tasks/$taskUuid/status';
    try {
      final response = await http.patch(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus, 'actor_uuid': actorUuid}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating task status: $e');
      return false;
    }
  }

  Future<bool> createTask(
    Map<String, dynamic> taskData,
    bool isMedication,
    String actorUuid,
  ) async {
    final endpoint = isMedication ? '$_apiUrl/medications' : '$_apiUrl/tasks';
    taskData['actor_uuid'] = actorUuid;
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(taskData),
      );
      if (response.statusCode == 201) {
        return true;
      } else {
        final responseBody = jsonDecode(response.body);
        throw Exception(responseBody['message'] ?? 'Failed to create task.');
      }
    } catch (e) {
      print('Error creating task: $e');
      rethrow;
    }
  }

  Future<bool> markTaskAsComplete(
    String taskType,
    String parentTaskUuid,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/completions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task_type': taskType,
          'parent_task_uuid': parentTaskUuid,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Error in markTaskAsComplete service: $e');
      return false;
    }
  }

  Future<bool> undoTaskCompletion(
    String taskType,
    String parentTaskUuid,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$_apiUrl/completions/undo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task_type': taskType,
          'parent_task_uuid': parentTaskUuid,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error in undoTaskCompletion service: $e');
      return false;
    }
  }

  Future<bool> deactivateTasks(List<String> taskUuids, String actorUuid) async {
    if (taskUuids.isEmpty) return true;
    final endpoint = '$_apiUrl/tasks/deactivate-batch';
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'task_uuids': taskUuids, 'actor_uuid': actorUuid}),
      );
      for (final uuid in taskUuids) {
        _notificationService.cancelNotificationsForTask(uuid);
      }
      return response.statusCode == 200;
    } catch (e) {
      print('Error deactivating tasks in batch: $e');
      return false;
    }
  }

  Future<bool> deleteTask(
    String taskUuid,
    String actorUuid,
    bool isMedication,
  ) async {
    final endpoint = isMedication
        ? '$_apiUrl/medications/$taskUuid'
        : '$_apiUrl/tasks/$taskUuid';
    try {
      final response = await http.delete(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'actor_uuid': actorUuid}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting task: $e');
      return false;
    }
  }

  Future<bool> updateTask({
    required String taskUuid,
    required bool isMedication,
    required Map<String, dynamic> newData,
    required String actorUuid,
  }) async {
    final endpoint = isMedication
        ? '$_apiUrl/medications/$taskUuid'
        : '$_apiUrl/tasks/$taskUuid';

    newData['actor_uuid'] = actorUuid;

    try {
      final response = await http.patch(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(newData),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating task: $e');
      return false;
    }
  }
}
