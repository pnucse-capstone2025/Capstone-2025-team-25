// lib/screens/send_task_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_request_model.dart';
import '../providers/task_request_provider.dart';
import '../widgets/send_task_form.dart'; 
import 'sent_requests_screen.dart';

class SendTaskScreen extends StatelessWidget {
  final TaskRequest? requestToEdit;
  const SendTaskScreen({super.key, this.requestToEdit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          requestToEdit != null ? 'Edit Task Request' : 'Send New Task',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.outbox),
            tooltip: 'View Sent Requests',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: Provider.of<TaskRequestProvider>(context, listen: false),
                  child: const SentRequestsScreen(),
                ),
              ));
            },
          )
        ],
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
            child: SendTaskForm(requestToEdit: requestToEdit),
          ),
        ],
      ),
    );
  }
}