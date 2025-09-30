// lib/screens/user_search_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import '../providers/chat_provider.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final ChatService _chatService = ChatService();
  List<ChatUser> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _search(query);
      } else {
        if (mounted) setState(() => _searchResults = []);
      }
    });
  }

  void _search(String query) async {
    setState(() => _isLoading = true);
    final actorUuid = Provider.of<UserProvider>(
      context,
      listen: false,
    ).userUuid;
    if (actorUuid != null) {
      try {
        final results = await _chatService.searchUsers(query, actorUuid);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('New Conversation'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withAlpha((0.4 * 255).round()),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withAlpha((0.3 * 255).round()),
                          ),
                        ),
                        child: TextField(
                          autofocus: true,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 15),
                            hintText: 'Search by nickname...',
                            hintStyle: TextStyle(
                              color: Colors.white.withAlpha((0.7 * 255).round()),
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.white,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isLoading
                      ? const LinearProgressIndicator()
                      : Expanded(
                          child: _searchResults.isEmpty
                              ? Center(
                                  child: Text(
                                    _searchQuery.isEmpty
                                        ? 'Find users to start a conversation'
                                        : 'No users found.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final user = _searchResults[index];
                                    return Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 6),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.blueGrey.withAlpha((0.4 * 255).round()),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.white.withAlpha((0.3 * 255).round()),
                                              ),
                                            ),
                                            child: ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: Colors.green.withAlpha((0.4 * 255).round()),
                                                backgroundImage: user.avatarUrl != null
                                                  ? NetworkImage(user.avatarUrl!)
                                                  : null,
                                                child: user.avatarUrl == null
                                                  ? Text(
                                                      user.displayName[0].toUpperCase(),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 20,
                                                      ),
                                                    )
                                                  : null,
                                              ),
                                              title: Text(
                                                user.displayName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              subtitle: Text(
                                                '@${user.username}',
                                                style: const TextStyle(color: Colors.white70),
                                              ),
                                              onTap: () => Navigator.of(context)
                                                  .pushReplacement(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ChangeNotifierProvider.value(
                                                    value: chatProvider,
                                                    child: ChatScreen(
                                                      partnerUser: user,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}