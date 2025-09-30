// lib/providers/chat_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';

class ChatProvider with ChangeNotifier {
  final ChatRepository _chatRepository = ChatRepository();

  List<Chat> _chats = [];
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _pollingTimer;
  String? activeChatUuid;
  bool _isDisposed = false;
  String? _userUuid;

  List<Chat> get chats => _chats;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  static const String chatbotUuid = '00000000-0000-0000-0000-000000000001';
  static final ChatUser chatbotUser = ChatUser(
    uuid: chatbotUuid,
    username: 'chatbot',
    displayName: 'AI Assistant',
    avatarUrl: null,
  );

  ChatProvider(this._userUuid);

  void updateUser(String? newUserUuid) {
    _userUuid = newUserUuid;
  }

  void clearChats() {
    _chats.clear();
    _messages.clear();
    notifyListeners();
  }

  Future<void> fetchChats(String userUuid) async {
    _isLoading = true;
    _errorMessage = null;
    if (!_isDisposed) notifyListeners();

    try {
      List<Chat> remoteChats = await _chatRepository.getChats(userUuid);

      Chat definitiveChatbotChat;
      int chatbotIndex = remoteChats.indexWhere(
        (chat) => chat.partnerUuid == chatbotUuid,
      );

      if (chatbotIndex != -1) {
        definitiveChatbotChat = remoteChats.removeAt(chatbotIndex);
      } else {
        definitiveChatbotChat = Chat(
          chatUuid: 'placeholder-chat-uuid',
          partnerUuid: chatbotUuid,
          partnerDisplayName: chatbotUser.displayName,
          partnerAvatarUrl: chatbotUser.avatarUrl,
          lastMessage: 'Ask me anything!',
          lastMessageSentAt: DateTime.now(),
          lastMessageSenderUuid: chatbotUuid,
          lastMessageStatus: 2, // Marked as read
        );
      }

      _chats = [definitiveChatbotChat, ...remoteChats];
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    if (!_isDisposed) notifyListeners();
  }

  Future<void> fetchMessages(String chatUuid, String userUuid) async {
    if (_messages.isEmpty) {
      _isLoading = true;
      if (!_isDisposed) notifyListeners();
    }
    try {
      _messages = await _chatRepository.getMessages(chatUuid, userUuid);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  void addOptimisticMessage(Message message) {
    _messages.add(message);
    notifyListeners();
  }

  Future<void> queryChatbot({
    required String userUuid,
    required String content,
  }) async {
    try {
      await _chatRepository.queryChatbot(userUuid: userUuid, content: content);
    } catch (e) {
      _errorMessage = e.toString();
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> synchronizeMessages() async {
    await _chatRepository.synchronizePendingMessages();
  }

  Future<Message?> sendMessage({
    required String senderUuid,
    required String recipientUuid,
    required String content,
    String? chatUuid,
  }) async {
    try {
      final newMessage = await _chatRepository.sendMessage(
        senderUuid: senderUuid,
        recipientUuid: recipientUuid,
        content: content,
        chatUuid: chatUuid,
      );

      if (chatUuid == null) {
        await fetchChats(senderUuid);
      }
      return newMessage;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
    return null;
  }

  void startPollingMessages(String chatUuid, String userUuid) {
    stopPollingMessages();
    if (chatUuid == 'placeholder-chat-uuid') return;

    fetchMessages(chatUuid, userUuid);
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      fetchMessages(chatUuid, userUuid);
    });
  }

  void stopPollingMessages() {
    _pollingTimer?.cancel();
  }

  @override
  void dispose() {
    stopPollingMessages();
    _isDisposed = true;
    super.dispose();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
