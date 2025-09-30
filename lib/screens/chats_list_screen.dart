import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../widgets/glass_container.dart';
import 'chat_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userUuid = Provider.of<UserProvider>(
        context,
        listen: false,
      ).userUuid;
      if (userUuid != null) {
        Provider.of<ChatProvider>(context, listen: false).fetchChats(userUuid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userUuid = Provider.of<UserProvider>(context, listen: false).userUuid;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
            ),
          ),
          
          CustomScrollView(
            slivers: [
              const SliverAppBar(
                title: Text('Messages'),
                pinned: true,
                floating: true,
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: GlassContainer(
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search chats...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 18,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 26,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
              
              SliverFillRemaining(
                child: Consumer<ChatProvider>(
                  builder: (context, provider, child) {
                    if (provider.errorMessage != null) {
                      return Center(
                        child: Text(
                          'An error occurred:\n${provider.errorMessage}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.redAccent,
                          ),
                        ),
                      );
                    }
                    if (provider.isLoading && provider.chats.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final filteredChats = provider.chats.where((chat) {
                      final partnerName = chat.partnerDisplayName.toLowerCase();
                      return partnerName.contains(_searchQuery.toLowerCase());
                    }).toList();

                    if (filteredChats.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No chats yet.\nStart a new conversation!'
                              : 'No chats found.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        if (userUuid != null) {
                          await provider.fetchChats(userUuid);
                        }
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = filteredChats[index];
                          final isLastMessageRead =
                              chat.lastMessageStatus == 2 ||
                              chat.lastMessageSenderUuid == userUuid;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: GlassContainer(
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 28,
                                  backgroundColor:
                                      chat.partnerUuid == ChatProvider.chatbotUuid
                                          ? Colors.blueGrey.withOpacity(0.5)
                                          : Colors.green.withOpacity(0.4),
                                  backgroundImage:
                                      chat.partnerAvatarUrl != null
                                          ? NetworkImage(chat.partnerAvatarUrl!)
                                          : null,
                                  child: chat.partnerAvatarUrl == null
                                      ? Text(
                                          chat.partnerDisplayName[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  chat.partnerDisplayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                subtitle: Text(
                                  chat.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isLastMessageRead
                                        ? Colors.white70
                                        : Colors.white,
                                    fontWeight: isLastMessageRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                trailing: Text(
                                  chat.lastMessageSentAt.isAfter(
                                    DateTime.now().subtract(const Duration(hours: 24)),
                                  )
                                      ? DateFormat('HH:mm').format(chat.lastMessageSentAt.toLocal())
                                      : DateFormat('MMM d').format(chat.lastMessageSentAt.toLocal()),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ChangeNotifierProvider.value(
                                          value: provider,
                                          child: ChatScreen(
                                            partnerUser: chat.partnerUuid == ChatProvider.chatbotUuid
                                                ? ChatProvider.chatbotUser
                                                : ChatUser(
                                                    uuid: chat.partnerUuid,
                                                    username: '',
                                                    displayName: chat.partnerDisplayName,
                                                    avatarUrl: chat.partnerAvatarUrl,
                                                  ),
                                            chatUuid: chat.chatUuid,
                                          ),
                                        ),
                                  ),
                                ).then((_) {
                                  if (userUuid != null) {
                                    provider.fetchChats(userUuid);
                                  }
                                }),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}