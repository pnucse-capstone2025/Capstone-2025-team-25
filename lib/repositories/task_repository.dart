// lib/repositories/task_repository.dart
import 'dart:io';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../services/database_helper.dart';
import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';
import '../providers/notification_provider.dart';
import 'package:flutter/material.dart';

class TaskRepository {
  final TaskService _taskService = TaskService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final NotificationService _notificationService = NotificationService();

  Future<bool> _isConnected() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<bool> updateTaskStatus(
    String taskUuid,
    String newStatus,
    String actorUuid,
    bool isMedication,
  ) async {
    if (kIsWeb) {
      return await _taskService.updateTaskStatus(
        taskUuid,
        newStatus,
        actorUuid,
        isMedication,
      );
    }
    if (await _isConnected()) {
      try {
        return await _taskService.updateTaskStatus(
          taskUuid,
          newStatus,
          actorUuid,
          isMedication,
        );
      } catch (e) {
        print('Failed to sync status update: $e');
        return false;
      }
    } else {
      return true;
    }
  }

  Future<List<AppTask>> fetchTasks(String userUuid) async {
    final NotificationProvider _notificationProvider = NotificationProvider();

    if (kIsWeb) {
      return await _taskService.fetchTasks(userUuid);
    }

    if (await _isConnected()) {
      try {
        final remoteTasks = await _taskService.fetchTasks(userUuid);
        final today = DateUtils.dateOnly(DateTime.now());
        print('TODAY: $today');
        final List<String> outdatedTaskUuids = [];
        final List<AppTask> activeAndCurrentTasks = [];

        for (final task in remoteTasks) {
          if (task.status == 'inactive' || task.status == 'deleted') continue;

          DateTime endDate = task.startDate ?? task.createdAt;
          if (task.rule?.durationDays != null && task.rule!.durationDays! > 0) {
            endDate = endDate.add(Duration(days: task.rule!.durationDays!));
          }

          if (DateUtils.dateOnly(endDate).isBefore(today)) {
            outdatedTaskUuids.add(task.uuid);
          } else {
            activeAndCurrentTasks.add(task);
          }
        }

        if (outdatedTaskUuids.isNotEmpty) {
          print(
            'Deactivating ${outdatedTaskUuids.length} outdated tasks in a single batch...',
          );
          await _taskService.deactivateTasks(outdatedTaskUuids, userUuid);
        }

        await _dbHelper.clearTasks();
        for (final task in activeAndCurrentTasks) {
          await _dbHelper.insertOrUpdateTask(
            task.copyWith(isSynced: true).toMap(),
          );
          await _notificationProvider.scheduleTaskNotifications(task);
        }
        return activeAndCurrentTasks;
      } catch (e) {
        return _dbHelper.getAllTasks();
      }
    } else {
      return _dbHelper.getAllTasks();
    }
  }

  Future<bool> createTask(
    Map<String, dynamic> taskData,
    bool isMedication,
    String actorUuid,
  ) async {
    if (kIsWeb) {
      return await _taskService.createTask(taskData, isMedication, actorUuid);
    }
    final rulesList = taskData['rules'] as List<dynamic>?;
    Map<String, dynamic>? ruleData;
    if (rulesList != null && rulesList.isNotEmpty) {
      ruleData = rulesList.first as Map<String, dynamic>;
    }
    final tempUuid = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final tempTask = AppTask(
      uuid: tempUuid,
      name: taskData['name'] ?? 'Untitled Task',
      description: taskData['description'],
      senderDisplayName: taskData['sender_display_name'],
      status: taskData['status'] ?? 'pending',
      createdAt: DateTime.now(),
      validUntil: taskData['valid_until'] != null
          ? DateTime.tryParse(taskData['valid_until'])
          : null,
      startDate: taskData['start_date'] != null
          ? DateTime.tryParse(taskData['start_date'])
          : null,
      isMedication: isMedication,
      rule: ruleData != null ? TaskRule.fromJson(ruleData) : null,
      isSynced: false,
    );

    if (await _isConnected()) {
      try {
        final success = await _taskService.createTask(
          taskData,
          isMedication,
          actorUuid,
        );
        if (success) {
          print('Task created on server successfully.');
          return true;
        }
        return false;
      } catch (e) {
        if (kDebugMode) {
          print('Failed to create task on server: $e');
        }
        return false;
      }
    } else {
      await _dbHelper.localCreateTask(tempTask.toMap());
    }
    return true;
  }

  Future<void> synchronizePendingTasks(
    String actorUuid,
    String userUuid,
  ) async {
    if (kIsWeb) {
      return;
    }
    if (await _isConnected()) {
      final unsyncedTasks = await _dbHelper.getUnsyncedTasks();

      if (kDebugMode) {
        print('Found ${unsyncedTasks.length} unsynced tasks. Starting sync...');
      }

      for (final task in unsyncedTasks) {
        try {
          if (task.uuid.startsWith('local_')) {
            final taskDataForApi = {
              'name': task.name,
              'description': task.description,
              'assignee_uuid': userUuid,
              'sender_uuid': actorUuid,
              'status': task.status,
              'start_date': task.startDate?.toIso8601String(),
              'valid_until': task.validUntil?.toIso8601String(),
              'rules': task.rule != null ? [task.rule!.toJson()] : [],
            };

            taskDataForApi.removeWhere((key, value) => value == null);

            final success = await _taskService.createTask(
              taskDataForApi,
              task.isMedication,
              actorUuid,
            );

            if (success) {
              await _dbHelper.insertOrUpdateTask(
                task.copyWith(isSynced: true).toMap(),
              );
            }
          } else {
            final success = await _taskService.markTaskAsComplete(
              task.isMedication ? 'medication' : 'task',
              task.uuid,
            );

            if (success) {
              await _dbHelper.insertOrUpdateTask(
                task.copyWith(isSynced: true).toMap(),
              );
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed to sync task ${task.uuid}: $e');
          }
        }
      }
      if (kDebugMode) {
        print('Sync process completed.');
      }
    }
  }

  Future<bool> markTaskAsComplete(AppTask task) async {
    if (kIsWeb) {
      return await _taskService.markTaskAsComplete(
        task.isMedication ? 'medication' : 'task',
        task.uuid,
      );
    }
    task.completedOccurrences++;
    if (task.completedOccurrences >= task.totalOccurrences) {
      task.isCompletedToday = true;
      if (task.rule?.durationDays != null) {
        task.totalDaysCompleted++;
      }
    }
    _notificationService.cancelNotificationsForTask(task.uuid);
    await _dbHelper.localUpdateTask(task.copyWith(isSynced: false).toMap());

    if (await _isConnected()) {
      final success = await _taskService.markTaskAsComplete(
        task.isMedication ? 'medication' : 'task',
        task.uuid,
      );
      if (success) {
        await _dbHelper.localUpdateTask(task.copyWith(isSynced: true).toMap());
        return true;
      }
      return false;
    }
    return true;
  }

  Future<bool> undoTaskCompletion(AppTask task) async {
    if (kIsWeb) {
      return await _taskService.undoTaskCompletion(
        task.isMedication ? 'medication' : 'task',
        task.uuid,
      );
    }
    task.completedOccurrences--;
    task.isCompletedToday = false;
    if (task.rule?.durationDays != null) {
      task.totalDaysCompleted--;
    }
    await _dbHelper.localUpdateTask(task.copyWith(isSynced: false).toMap());

    if (await _isConnected()) {
      final success = await _taskService.undoTaskCompletion(
        task.isMedication ? 'medication' : 'task',
        task.uuid,
      );
      if (success) {
        await _dbHelper.localUpdateTask(task.copyWith(isSynced: true).toMap());
        return true;
      }
      return false;
    }
    return true;
  }

  Future<bool> deleteTask(AppTask task, String actorUuid) async {

    if (kIsWeb) {
      return await _taskService.deleteTask(
        task.uuid,
        actorUuid,
        task.isMedication,
      );
    }
    await _dbHelper.deleteTask(task.uuid);
    _notificationService.cancelNotificationsForTask(task.uuid);
    if (kIsWeb || await _isConnected()) {
      try {
        return await _taskService.deleteTask(
          task.uuid,
          actorUuid,
          task.isMedication,
        );
      } catch (e) {
        print('Failed to sync deletion: $e');
        return false;
      }
    }
    return true;
  }

  Future<bool> updateTask({
    required AppTask taskToUpdate,
    required Map<String, dynamic> newData,
    required String actorUuid,
  }) async {

    if (kIsWeb || await _isConnected()) {
      return await _taskService.updateTask(
        taskUuid: taskToUpdate.uuid,
        isMedication: taskToUpdate.isMedication,
        newData: newData,
        actorUuid: actorUuid,
      );
    }
    return false;
  }
}
