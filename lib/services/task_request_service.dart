// lib/services/task_request_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/task_request_model.dart';
import '../utils/constants.dart';

class TaskRequestService {
  final String _apiUrl = '$kBaseUrl/api';

  Future<dynamic> parsePrescription(
    Uint8List imageBytes,
    String filename,
  ) async {
    final uri = Uri.parse('$_apiUrl/prescriptions/parse');
    final request = http.MultipartRequest('POST', uri);

    final extension = filename.split('.').last.toLowerCase();

    request.files.add(
      http.MultipartFile.fromBytes(
        'prescription',
        imageBytes,
        filename: filename,
        contentType: MediaType('image', extension),
      ),
    );

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        if (data is Map<String, dynamic> &&
            data['success'] == true &&
            data['tasks'] is List) {
          return data['tasks']; 
        } else {
          final details =
              data['details'] ?? data['error'] ?? 'No details provided.';
          throw Exception('Failed to parse prescription: $details');
        }
      } else {
        final errorData = jsonDecode(responseBody);
        final errorMessage = errorData['message'] ?? 'Unknown server error.';
        final errorDetails = errorData['details'] ?? responseBody;
        throw Exception(
          'Failed to parse prescription ($errorMessage): $errorDetails',
        );
      }
    } catch (e) {
      print('Error in parsePrescription service: $e');
      throw Exception('Could not connect to the server to parse prescription.');
    }
  }

  Future<bool> sendMultipleTaskRequests({
    required String senderUuid,
    required String assigneeUuid,
    required List<Map<String, dynamic>> tasks,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiUrl/task_requests/batch'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender_uuid': senderUuid,
        'assignee_uuid': assigneeUuid,
        'tasks': tasks,
      }),
    );
    if (response.statusCode != 201) {
      print("Batch request failed with status: ${response.statusCode}");
      print("Response body: ${response.body}");
    }
    return response.statusCode == 201;
  }

  Future<List<TaskRequest>> getPendingRequests(String userUuid) async {
    final response = await http.get(
      Uri.parse('$_apiUrl/task_requests?user_uuid=$userUuid'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['requests'] as List)
          .map((req) => TaskRequest.fromReceivedJson(req))
          .toList();
    } else {
      throw Exception('Failed to fetch pending requests.');
    }
  }

  Future<List<TaskRequest>> getSentRequests(String userUuid) async {
    final response = await http.get(
      Uri.parse('$_apiUrl/task_requests/sent?user_uuid=$userUuid'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['requests'] as List)
          .map((req) => TaskRequest.fromSentJson(req))
          .toList();
    } else {
      throw Exception('Failed to fetch sent requests.');
    }
  }

  Future<bool> sendTaskRequest({
    required String senderUuid,
    required String assigneeUuid,
    required String taskType,
    required Map<String, dynamic> taskData,
  }) async {
    final response = await http.post(
      Uri.parse('$_apiUrl/task_requests'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender_uuid': senderUuid,
        'assignee_uuid': assigneeUuid,
        'task_type': taskType,
        'task_data': taskData,
      }),
    );
    return response.statusCode == 201;
  }

  Future<bool> updateSentRequest({
    required String requestUuid,
    required String actorUuid,
    required Map<String, dynamic> taskData,
  }) async {
    final response = await http.put(
      Uri.parse('$_apiUrl/task_requests/$requestUuid'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'actor_uuid': actorUuid, 'task_data': taskData}),
    );
    return response.statusCode == 200;
  }

  Future<bool> updateTaskRequestStatus({
    required String requestUuid,
    required String status,
    required String actorUuid,
  }) async {
    final response = await http.patch(
      Uri.parse('$_apiUrl/task_requests/$requestUuid'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status, 'actor_uuid': actorUuid}),
    );
    return response.statusCode == 200;
  }

  Future<bool> deleteSentRequest(String requestUuid, String actorUuid) async {
    final response = await http.delete(
      Uri.parse('$_apiUrl/task_requests/$requestUuid'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'actor_uuid': actorUuid}),
    );
    return response.statusCode == 200;
  }
}
