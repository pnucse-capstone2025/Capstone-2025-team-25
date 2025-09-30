// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_request_model.dart';
import '../providers/task_request_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/glass_container.dart'; // Import our glass widget

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userUuid = Provider.of<UserProvider>(context, listen: false).userUuid;
      if (userUuid != null) {
        Provider.of<TaskRequestProvider>(context, listen: false).fetchReceivedRequests(userUuid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Apply transparent background and extend the body
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // The title will be automatically styled by the global theme
        title: const Text('Task Requests'),
      ),
      body: Stack(
        children: [
          // Background Image
          SizedBox.expand(
            child: Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
            ),
          ),
          // Main Content
          SafeArea(
            child: Consumer<TaskRequestProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.receivedRequests.isEmpty) {
                  // Style the "empty" message for better readability
                  return const Center(
                    child: Text(
                      'No pending task requests.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    final userUuid = Provider.of<UserProvider>(context, listen: false).userUuid;
                    if (userUuid != null) await provider.fetchReceivedRequests(userUuid);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: provider.receivedRequests.length,
                    itemBuilder: (context, index) {
                      final request = provider.receivedRequests[index];
                      return TaskRequestCard(request: request);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TaskRequestCard extends StatelessWidget {
  final TaskRequest request;
  const TaskRequestCard({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskRequestProvider>(context, listen: false);
    final actorUuid = Provider.of<UserProvider>(context, listen: false).userUuid;

    // Replace Card with Padding and GlassContainer
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassContainer(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  // Style the text to be white
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  text: 'New ${request.taskType} request from ',
                  children: [
                    TextSpan(
                      text: request.partnerDisplayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '"${request.taskName}"',
                // Style the text to be white
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      if (actorUuid != null) provider.respondToRequest(request.requestUuid, 'declined', actorUuid);
                    },
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (actorUuid != null) provider.respondToRequest(request.requestUuid, 'accepted', actorUuid);
                    },
                    child: const Text('Accept'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}