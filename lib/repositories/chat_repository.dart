// lib/repositories/chat_repository.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/chat_database_helper.dart';

class ChatRepository {
  final ChatService _chatService = ChatService();
  final ChatDatabaseHelper _dbHelper = ChatDatabaseHelper.instance;

  Future<bool> _isConnected() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<List<ChatUser>> searchUsers(String username, String actorUuid) async {
    return _chatService.searchUsers(username, actorUuid);
  }


  Future<List<Chat>> getChats(String userUuid) async {
    if (kIsWeb) {
      return await _chatService.getChats(userUuid);
    }
    if (await _isConnected()) {
      try {
        final remoteChats = await _chatService.getChats(userUuid);

        await _dbHelper.clearChats();

        for (final chat in remoteChats) {
          await _dbHelper.insertOrUpdateChat(chat);

          try {
            final messages = await _chatService.getMessages(
              chat.chatUuid,
              userUuid,
            );
            for (final message in messages) {
              await _dbHelper.insertOrUpdateMessage(message);
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                'Could not pre-cache messages for chat ${chat.chatUuid}: $e',
              );
            }
          }
        }
        return remoteChats;
      } catch (e) {
        return _dbHelper.getChats();
      }
    } else {
      return _dbHelper.getChats();
    }
  }

  Future<List<Message>> getMessages(String chatUuid, String userUuid) async {
    if (kIsWeb) {
      return await _chatService.getMessages(chatUuid, userUuid);
    }
    if (await _isConnected()) {
      try {
        final remoteMessages = await _chatService.getMessages(
          chatUuid,
          userUuid,
        );
        for (final message in remoteMessages) {
          await _dbHelper.insertOrUpdateMessage(message);
        }
        return remoteMessages;
      } catch (e) {
        return _dbHelper.getMessages(chatUuid);
      }
    } else {
      return _dbHelper.getMessages(chatUuid);
    }
  }

  Future<Message?> sendMessage({
    required String senderUuid,
    required String recipientUuid,
    required String content,
    required String? chatUuid,
  }) async {
    if (kIsWeb) {
      return await _chatService.sendMessage(senderUuid, recipientUuid, content);
    }
    final effectiveChatUuid = chatUuid ?? 'new_chat_with_${recipientUuid}';

    final tempMessage = Message(
      uuid: 'local_${DateTime.now().millisecondsSinceEpoch}',
      chatUuid: effectiveChatUuid,
      senderUuid: senderUuid,
      recipientUuid: recipientUuid,
      content: content,
      sentAt: DateTime.now(),
      status: 0,
      isSynced: false,
    );
    await _dbHelper.insertOrUpdateMessage(tempMessage);

    if (await _isConnected()) {
      try {
        final syncedMessage = await _chatService.sendMessage(
          senderUuid,
          recipientUuid,
          content,
        );
        if (syncedMessage != null) {
          await _dbHelper.deleteMessageByUuid(tempMessage.uuid);
          await _dbHelper.insertOrUpdateMessage(syncedMessage);
          return syncedMessage;
        }
      } catch (e) {
        if (kDebugMode) print('Failed to send message, saved locally: $e');
      }
    }
    return tempMessage;
  }

  Future<void> queryChatbot({
    required String userUuid,
    required String content,
  }) async {
    if (kIsWeb) {
      return await _chatService.queryChatbot(userUuid, content);
    }
    if (!await _isConnected()) {
      throw Exception("You must be online to talk to the AI Assistant.");
    }
    await _chatService.queryChatbot(userUuid, content);
  }

  Future<void> synchronizePendingMessages() async {
    if (kIsWeb) {
      return;
    }
    if (await _isConnected()) {
      final unsyncedMessages = await _dbHelper.getUnsyncedMessages();
      for (final message in unsyncedMessages) {
        try {
          final syncedMessage = await _chatService.sendMessage(
            message.senderUuid,
            message
                .recipientUuid!,
            message.content,
          );
          if (syncedMessage != null) {
            await _dbHelper.deleteMessageByUuid(message.uuid);
            await _dbHelper.insertOrUpdateMessage(syncedMessage);
          }
        } catch (e) {
          if (kDebugMode) print('Failed to sync message ${message.uuid}: $e');
        }
      }
    }
  }
}
