// lib/providers/task_provider.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

import '../models/task_model.dart';
import '../models/ddi_conflict.dart';
import '../repositories/task_repository.dart';
import '../services/ddi_service.dart';
import 'user_provider.dart';

class TaskProvider with ChangeNotifier {
  final TaskRepository _taskRepository = TaskRepository();
  final DdiService _ddiService = DdiService(); 
  final UserProvider userProvider = UserProvider();

  String? _userUuid;
  List<AppTask> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;
  final List<DdiConflict> _conflicts = [];

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  TaskProvider(this._userUuid) {
    _initConnectivityListener();
  }

  List<AppTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<DdiConflict> get conflicts => _conflicts;


  void updateUser(String? newUserUuid) {
    _userUuid = newUserUuid;
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      if (result != ConnectivityResult.none) {
        print("🌍 Internet connection detected. Starting task sync...");
        if (_userUuid != null) {
          synchronizeTasks();
        }
      }
    });
  }

  Future<void> synchronizeTasks() async {
    if (_userUuid == null) return;
    await _taskRepository.synchronizePendingTasks(_userUuid!, _userUuid!);
    await loadTasks(_userUuid!);
  }

  Future<void> loadTasks(String userUuid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final fetchedTasks = await _taskRepository.fetchTasks(userUuid);
      _tasks = fetchedTasks.map((task) {
        _calculateOccurrences(task);
        task.isCompletedToday =
            task.completedOccurrences >= task.totalOccurrences;
        return task;
      }).toList();
      _tasks.sort(
        (a, b) =>
            (a.startDate ?? a.createdAt).compareTo(b.startDate ?? b.createdAt),
      );

      await _checkAllTaskInteractions();
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _checkAllTaskInteractions() async {
    _conflicts.clear();
    final medicationTasks = _tasks
        .where((t) => t.isMedication && t.medicationId != null)
        .toList();

    final Set<String> checkedPairs = {};

    for (final taskA in medicationTasks) {
      for (final taskB in medicationTasks) {
        if (taskA.uuid == taskB.uuid) continue;

        final pairKey = [taskA.uuid, taskB.uuid]..sort();
        if (checkedPairs.contains(pairKey.join('-'))) {
          continue;
        }

        final interactionLevel = await _ddiService.getInteractionLevel(
          taskA.medicationId!,
          taskB.medicationId!,
        );

        if (interactionLevel != null) {
          _conflicts.add(
            DdiConflict(
              taskUuid1: taskA.uuid,
              taskName1: taskA.name,
              taskUuid2: taskB.uuid,
              taskName2: taskB.name,
              level: interactionLevel,
            ),
          );
        }

        checkedPairs.add(pairKey.join('-'));
      }
    }
  }

  Future<bool> createTask({
    required Map<String, dynamic> taskData,
    required bool isMedication,
    required String actorUuid,
    required String userUuidForRefresh,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final success = await _taskRepository.createTask(
        taskData,
        isMedication,
        actorUuid,
      );
      if (success) {
        await loadTasks(userUuidForRefresh);
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> markTaskAsComplete(AppTask task) async {
    if (_userUuid == null) {
      _errorMessage = "Cannot complete task: User not logged in.";
      notifyListeners();
      return;
    }
    final originalCompleted = task.completedOccurrences;
    final originalIsCompletedToday = task.isCompletedToday;
    final originalStatus = task.status;

    task.completedOccurrences++;
    if (task.completedOccurrences >= task.totalOccurrences) {
      task.isCompletedToday = true;
    }

    bool shouldDeactivate = false;
    if ((task.rule == null || task.rule!.durationDays == null) &&
        task.isCompletedToday) {
      shouldDeactivate = true;
    } else if (task.rule?.durationDays != null) {
      final rule = task.rule!;
      final startDate = DateUtils.dateOnly(task.startDate ?? task.createdAt);
      final today = DateUtils.dateOnly(DateTime.now());
      final lastDay = startDate.add(Duration(days: rule.durationDays! - 1));

      if (!today.isBefore(lastDay) && task.isCompletedToday) {
        shouldDeactivate = true;
      }
    }

    if (shouldDeactivate) {
      task.status = 'inactive';
    }

    notifyListeners();

    bool completionSuccess = await _taskRepository.markTaskAsComplete(task);
    bool statusUpdateSuccess = true;
    if (shouldDeactivate) {
      statusUpdateSuccess = await _taskRepository.updateTaskStatus(
        task.uuid,
        'inactive',
        _userUuid!,
        task.isMedication,
      );
    }

    if (!completionSuccess || !statusUpdateSuccess) {
      task.completedOccurrences = originalCompleted;
      task.isCompletedToday = originalIsCompletedToday;
      task.status = originalStatus;
      _errorMessage = "Failed to sync task completion.";
      notifyListeners();
    }
  }

  Future<void> undoLastCompletion(AppTask task) async {
    final originalCompleted = task.completedOccurrences;
    final originalDaysCompleted = task.totalDaysCompleted;
    final wasCompletedToday = task.isCompletedToday;

    task.completedOccurrences--;
    task.isCompletedToday = false;
    if (wasCompletedToday && task.rule?.durationDays != null) {
      task.totalDaysCompleted--;
    }
    notifyListeners();

    final success = await _taskRepository.undoTaskCompletion(task);

    if (!success) {
      task.completedOccurrences = originalCompleted;
      task.totalDaysCompleted = originalDaysCompleted;
      task.isCompletedToday = wasCompletedToday;
      _errorMessage = "Failed to undo completion.";
      notifyListeners();
    }
  }

  Future<void> deleteTask(AppTask task, String actorUuid) async {
    final int taskIndex = _tasks.indexOf(task);
    _tasks.remove(task);
    notifyListeners();

    final success = await _taskRepository.deleteTask(task, actorUuid);

    if (!success) {
      _tasks.insert(taskIndex, task);
      _errorMessage = "Failed to delete task. Please try again.";
      notifyListeners();
    }
  }

  Future<bool> updateTask({
    required AppTask taskToUpdate,
    required Map<String, dynamic> newData,
    required String actorUuid,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _taskRepository.updateTask(
        taskToUpdate: taskToUpdate,
        newData: newData,
        actorUuid: actorUuid,
      );
      if (success && _userUuid != null) {
        await loadTasks(_userUuid!);
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _calculateOccurrences(AppTask task) {
    if (task.rule == null) {
      task.totalOccurrences = 1;
      return;
    }
    final rule = task.rule!;
    int total = 0;
    switch (rule.ruleType) {
      case 'once':
        total = 1;
        break;
      case 'n_times':
        total = rule.count ?? 1;
        break;
      case 'interval':
        if (rule.intervalHours != null && rule.intervalHours! > 0) {
          total = (24 / rule.intervalHours!).floor();
        } else {
          total = 1;
        }
        break;
      case 'meal_based':
        try {
          final extras = jsonDecode(rule.extras ?? '{}');
          final meals = extras['meals'] as List?;
          total = meals?.length ?? 1;
        } catch (e) {
          total = 1;
        }
        break;
      case 'bedtime':
        total = 1;
        break;
      default:
        total = 1;
    }
    task.totalOccurrences = total;
  }

  void clearTasks() {
    _tasks.clear();
    _conflicts.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
