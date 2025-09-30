// lib/services/chat_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class ChatService {
  final String _apiUrl = '$kBaseUrl/api';
  final NotificationService _notificationService = NotificationService();

  Future<List<ChatUser>> searchUsers(String username, String actorUuid) async {
    final response = await http.get(
      Uri.parse(
        '$_apiUrl/chats/search?username=$username&actor_uuid=$actorUuid',
      ),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['users'] as List)
          .map((user) => ChatUser.fromJson(user))
          .toList();
    } else {
      throw Exception('Failed to search users.');
    }
  }

  Future<List<Chat>> getChats(String userUuid) async {
    final response = await http.get(
      Uri.parse('$_apiUrl/chats?user_uuid=$userUuid'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['chats'] as List)
          .map((chat) => Chat.fromJson(chat, userUuid))
          .toList();
    } else {
      throw Exception('Failed to fetch chats.');
    }
  }

  Future<List<Message>> getMessages(String chatUuid, String userUuid) async {
    final response = await http.get(
      Uri.parse('$_apiUrl/chats/$chatUuid/messages?user_uuid=$userUuid'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['messages'] as List)
          .map((msg) => Message.fromJson(msg))
          .toList();
    } else {
      throw Exception('Failed to fetch messages.');
    }
  }

  Future<Message?> sendMessage(
    String senderUuid,
    String recipientUuid,
    String content,
  ) async {
    final response = await http.post(
      Uri.parse('$_apiUrl/chats/messages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender_uuid': senderUuid,
        'recipient_uuid': recipientUuid,
        'content': content,
      }),
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Message.fromJson(data['newMessage']);
    }
    return null;
  }

  Future<void> queryChatbot(String userUuid, String query) async {
    final response = await http.post(
      Uri.parse('$_apiUrl/chatbot/query'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_uuid': userUuid, 'query': query}),
    );

    if (response.statusCode != 200) {
      final errorBody = jsonDecode(response.body);
      throw Exception(
        'Failed to send query to chatbot: ${errorBody['message']}',
      );
    }
  }
}
