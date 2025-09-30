import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/task_request_model.dart';
import '../models/task_model.dart';
import '../services/task_request_service.dart';
import 'notification_provider.dart';
import '../services/task_service.dart';


class TaskRequestProvider with ChangeNotifier {
  final TaskRequestService _requestService = TaskRequestService();
  final NotificationProvider _notificationProvider = NotificationProvider();
  final TaskService _taskService = TaskService();
  List<TaskRequest> _receivedRequests = [];
  List<TaskRequest> _sentRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<TaskRequest> get receivedRequests => _receivedRequests;
  List<TaskRequest> get sentRequests => _sentRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchReceivedRequests(String userUuid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _receivedRequests = await _requestService.getPendingRequests(userUuid);
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchSentRequests(String userUuid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _sentRequests = await _requestService.getSentRequests(userUuid);
    } catch (e) {
      _errorMessage = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }
  
  Future<bool> respondToRequest(String requestUuid, String status, String actorUuid) async {
    try {
      final requestIndex = _receivedRequests.indexWhere((req) => req.requestUuid == requestUuid);
      if (requestIndex == -1) {
        _errorMessage = "Request not found locally.";
        notifyListeners();
        return false;
      }
      final TaskRequest request = _receivedRequests[requestIndex];

      final success = await _requestService.updateTaskRequestStatus(
        requestUuid: requestUuid,
        status: status,
        actorUuid: actorUuid,
      );

      if (success) {
        if (status == 'accepted') {
          try {
            final idField = request.taskType == 'medication' ? 'med_task_uuid' : 'task_uuid';
            final rulesList = request.taskData['rules'] as List?;
            final ruleData = (rulesList != null && rulesList.isNotEmpty) ? rulesList.first as Map<String, dynamic> : {};
            
            final Map<String, dynamic> taskDataWithId = {
              ...request.taskData,
              ...ruleData,
              idField: request.requestUuid,
              'assignee_uuid': actorUuid,
              'sender_uuid': request.partnerUuid,
              'status': 'pending',
            };
            
            final AppTask newTask = AppTask.fromJson(taskDataWithId, isMedication: request.taskType == 'medication');
            
            await _notificationProvider.scheduleTaskNotifications(newTask);
            _taskService.fetchTasks(actorUuid);
            print('✅ Notifications scheduled for accepted task: ${newTask.name}');

          } catch (e) {
            print('Error creating task or scheduling notifications from accepted request: $e');
            _errorMessage = 'Task accepted, but failed to schedule notifications.';
          }
        }
        _receivedRequests.removeAt(requestIndex);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }


  Future<bool> sendMultipleRequests({
    required String senderUuid,
    required String assigneeUuid,
    required List<Map<String, dynamic>> tasks,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final success = await _requestService.sendMultipleTaskRequests(
        senderUuid: senderUuid,
        assigneeUuid: assigneeUuid,
        tasks: tasks,
      );
      _isLoading = false;
      if (!success) _errorMessage = 'Failed to send one or more tasks.';
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<dynamic>?> parsePrescription(Uint8List imageBytes, String fileName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final parsedData = await _requestService.parsePrescription(imageBytes, fileName);
      _isLoading = false;
      notifyListeners();
      return parsedData;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteSentRequest(String requestUuid, String actorUuid) async {
    try {
      final success = await _requestService.deleteSentRequest(requestUuid, actorUuid);
      if (success) {
        _sentRequests.removeWhere((req) => req.requestUuid == requestUuid);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSentRequest({
    required String requestUuid,
    required String actorUuid,
    required Map<String, dynamic> taskData,
  }) async {
    try {
      final success = await _requestService.updateSentRequest(
        requestUuid: requestUuid,
        actorUuid: actorUuid,
        taskData: taskData,
      );
      if (success) {
        await fetchSentRequests(actorUuid);
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}

