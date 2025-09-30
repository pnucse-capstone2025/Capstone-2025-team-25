// lib/screens/chat_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final ChatUser partnerUser;
  final String? chatUuid;
  const ChatScreen({super.key, required this.partnerUser, this.chatUuid});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatProvider _chatProvider;
  String? _currentChatUuid;

  @override
  void initState() {
    super.initState();
    _currentChatUuid = widget.chatUuid;
    _chatProvider = context.read<ChatProvider>();
    final userUuid = context.read<UserProvider>().userUuid;
    _chatProvider.activeChatUuid = widget.chatUuid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentChatUuid != null && userUuid != null) {
        _chatProvider.startPollingMessages(_currentChatUuid!, userUuid);
      } else {
        _chatProvider.clearMessages();
      }
    });
  }

  @override
  void dispose() {
    _chatProvider.stopPollingMessages();
    _messageController.dispose();
    _scrollController.dispose();
    _chatProvider.activeChatUuid = null;
    super.dispose();
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final userUuid = Provider.of<UserProvider>(context, listen: false).userUuid;
    if (userUuid == null) return;

    _messageController.clear();
    _chatProvider.stopPollingMessages();

    final optimisticMessage = Message(
      uuid: 'temp_${DateTime.now().toIso8601String()}',
      chatUuid: _currentChatUuid ?? 'placeholder',
      senderUuid: userUuid,
      recipientUuid: widget.partnerUser.uuid,
      content: content,
      sentAt: DateTime.now(),
      status: 0,
    );
    _chatProvider.addOptimisticMessage(optimisticMessage);
    _scrollToBottom();

    void handleCompletion() async {
      if (!mounted) return;

      bool isNewChat =
          _currentChatUuid == null ||
          _currentChatUuid == 'placeholder-chat-uuid';
      String chatUuidToPoll = _currentChatUuid ?? '';

      if (isNewChat) {
        await _chatProvider.fetchChats(userUuid);
        if (!mounted) return;
        final newChat = _chatProvider.chats.firstWhere(
          (c) => c.partnerUuid == widget.partnerUser.uuid,
        );
        chatUuidToPoll = newChat.chatUuid;
        setState(() {
          _currentChatUuid = chatUuidToPoll;
        });
      }

      await _chatProvider.fetchMessages(chatUuidToPoll, userUuid);

      if (mounted) {
        _chatProvider.startPollingMessages(chatUuidToPoll, userUuid);
      }
    }

    if (widget.partnerUser.uuid == ChatProvider.chatbotUuid) {
      _chatProvider
          .queryChatbot(userUuid: userUuid, content: content)
          .whenComplete(handleCompletion);
    } else {
      _chatProvider
          .sendMessage(
            senderUuid: userUuid,
            recipientUuid: widget.partnerUser.uuid,
            content: content,
            chatUuid: _currentChatUuid,
          )
          .whenComplete(handleCompletion);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userUuid = Provider.of<UserProvider>(context, listen: false).userUuid;
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.partnerUser.displayName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),
          Container(
            color: Colors.black.withOpacity(0.15),
            child: Column(
              children: [
                Expanded(
                  child: chatProvider.isLoading && chatProvider.messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.only(top: 100, bottom: 10),
                          itemCount: chatProvider.messages.length,
                          itemBuilder: (context, index) {
                            final message = chatProvider.messages.reversed
                                .toList()[index];
                            final isMe = message.senderUuid == userUuid;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: MessageBubble(
                                message: message,
                                isMe: isMe,
                              ),
                            );
                          },
                        ),
                ),
                _buildMessageInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          color: Colors.black54,
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: Colors.green.shade700,
                      size: 28,
                    ),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
