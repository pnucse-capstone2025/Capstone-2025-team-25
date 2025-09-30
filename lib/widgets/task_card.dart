// lib/widgets/task_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../providers/user_provider.dart';
import '../screens/create_task_screen.dart';

class TaskCard extends StatelessWidget {
  final AppTask task;
  final bool hasConflict; 

  const TaskCard({
    super.key,
    required this.task,
    this.hasConflict = false, 
  });

  void _showDeleteConfirmation(
    BuildContext context,
    TaskProvider provider,
    String userUuid,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to permanently delete this task?'),
        actions: <Widget>[
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Delete'),
            onPressed: () {
              provider.deleteTask(task, userUuid);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final userUuid = Provider.of<UserProvider>(context, listen: false).userUuid;

    final double progress = (task.totalOccurrences > 0)
        ? task.completedOccurrences / task.totalOccurrences
        : 0.0;

    final bool isCompleted = progress >= 1.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked_outlined,
                    color: isCompleted ? Colors.green : Colors.grey.shade400,
                    size: 32,
                  ),
                  onPressed: () {
                    if (!isCompleted) {
                      taskProvider.markTaskAsComplete(task);
                    }
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              task.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isCompleted ? Colors.grey : null,
                                  ),
                            ),
                          ),
                          if (hasConflict)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Tooltip(
                                message: 'Potential drug interaction detected.',
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (task.senderDisplayName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'From: ${task.senderDisplayName}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                            value: taskProvider,
                            child: CreateTaskScreen(taskToEdit: task),
                          ),
                        ),
                      );
                    } else if (value == 'delete') {
                      if (userUuid != null) {
                        _showDeleteConfirmation(
                          context,
                          taskProvider,
                          userUuid,
                        );
                      }
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Modify'),
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                ),
              ],
            ),
            if (task.description?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(
                  top: 8.0,
                  left: 48,
                ), 
                child: Text(
                  task.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isCompleted ? Colors.grey : Colors.black87,
                  ),
                ),
              ),
            if (task.totalOccurrences > 1) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(width: 48), 
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.green,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${task.completedOccurrences}/${task.totalOccurrences}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
