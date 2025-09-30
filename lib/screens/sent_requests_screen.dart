// lib/screens/sent_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_request_model.dart';
import '../providers/task_request_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/glass_container.dart';
import 'send_task_screen.dart';

class SentRequestsScreen extends StatefulWidget {
  const SentRequestsScreen({super.key});

  @override
  State<SentRequestsScreen> createState() => _SentRequestsScreenState();
}

class _SentRequestsScreenState extends State<SentRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userUuid = Provider.of<UserProvider>(context, listen: false).userUuid;
      if (userUuid != null) {
        Provider.of<TaskRequestProvider>(context, listen: false).fetchSentRequests(userUuid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskRequestProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent, 
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Sent Requests'),
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.sentRequests.isEmpty
                    ? const Center(
                        child: Text(
                          'You have not sent any requests.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          final userUuid = Provider.of<UserProvider>(context, listen: false).userUuid;
                          if (userUuid != null) await provider.fetchSentRequests(userUuid);
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 8),
                          itemCount: provider.sentRequests.length,
                          itemBuilder: (context, index) {
                            final request = provider.sentRequests[index];
                            return SentRequestCard(request: request);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class SentRequestCard extends StatelessWidget {
  final TaskRequest request;
  const SentRequestCard({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskRequestProvider>(context, listen: false);
    final actorUuid = Provider.of<UserProvider>(context, listen: false).userUuid;
    final bool isPending = request.status == 'pending';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassContainer(
        child: ExpansionTile(
          title: Text(
            request.taskName,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          subtitle: Text(
            'To: ${request.partnerDisplayName} - Status: ${request.status}',
            style: const TextStyle(color: Colors.white70),
          ),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white70,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.taskDescription,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isPending) ...[
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Request'),
                                      content: const Text('Are you sure you want to delete this pending request?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                                        TextButton(
                                            onPressed: () {
                                              if (actorUuid != null) provider.deleteSentRequest(request.requestUuid, actorUuid);
                                              Navigator.of(ctx).pop();
                                            },
                                            child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                      ],
                                    ));
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: Colors.blue.shade300),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider.value(
                                value: provider,
                                child: SendTaskScreen(requestToEdit: request),
                              ),
                            ));
                          },
                        ),
                      ]
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}