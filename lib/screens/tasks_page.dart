// lib/screens/tasks_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ddi_conflict.dart';
import '../models/task_model.dart';
import '../providers/ddi_provider.dart';
import '../providers/user_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/glass_container.dart'; 
import '../widgets/task_card.dart';
import 'create_task_screen.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.userUuid != null) {
        Provider.of<TaskProvider>(
          context,
          listen: false,
        ).loadTasks(userProvider.userUuid!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final taskProvider = Provider.of<TaskProvider>(
            context,
            listen: false,
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: taskProvider),
                  ChangeNotifierProvider(create: (_) => DdiProvider()),
                ],
                child: const CreateTaskScreen(),
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),
          Consumer<TaskProvider>(
            builder: (context, taskProvider, child) {
              if (taskProvider.isLoading && taskProvider.tasks.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (taskProvider.errorMessage != null) {
                return Center(
                  child: Text(
                    'Error: ${taskProvider.errorMessage}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              if (taskProvider.tasks.isEmpty) {
                return const Center(
                  child: Text(
                    'No tasks found.\nTap the + button to add one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                );
              }

              final today = DateUtils.dateOnly(DateTime.now());

              final todaysTasks = taskProvider.tasks
                  .where((task) =>
                      !DateUtils.dateOnly(task.startDate ?? task.createdAt)
                          .isAfter(today) &&
                      !task.isCompletedToday)
                  .toList();

              final upcomingTasks = taskProvider.tasks
                  .where((task) =>
                      !todaysTasks.contains(task) && !task.isCompletedToday)
                  .toList();

              final conflictingUuids = taskProvider.conflicts
                  .expand((c) => [c.taskUuid1, c.taskUuid2])
                  .toSet();

              return RefreshIndicator(
                onRefresh: () async {
                  final userUuid = Provider.of<UserProvider>(
                    context,
                    listen: false,
                  ).userUuid;
                  if (userUuid != null) {
                    await taskProvider.loadTasks(userUuid);
                  }
                },
                child: CustomScrollView(
                  slivers: [
                    const SliverAppBar(
                      title: Text('My Tasks'),
                      pinned: true,
                      floating: true,
                    ),
                    if (taskProvider.conflicts.isNotEmpty)
                      _buildOverallDdiWarning(taskProvider.conflicts),
                    _buildTaskList(
                      "Today",
                      todaysTasks,
                      context,
                      conflictingUuids,
                    ),
                    _buildTaskList(
                      "Upcoming",
                      upcomingTasks,
                      context,
                      conflictingUuids,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverallDdiWarning(List<DdiConflict> conflicts) {
    final uniqueConflicts = {
      for (var c in conflicts)
        ([c.taskName1, c.taskName2]..sort()).join(' and '): c.level,
    };

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade100.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
                const SizedBox(width: 8),
                Text(
                  'Drug Interaction Warning',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The following medications may interact with each other:',
              style: TextStyle(color: Colors.red.shade900),
            ),
            const SizedBox(height: 4),
            ...uniqueConflicts.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  '• ${entry.key} (Level: ${entry.value})',
                  style: TextStyle(color: Colors.red.shade900),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(
    String title,
    List<AppTask> tasks,
    BuildContext context,
    Set<String> conflictingUuids,
  ) {
    return SliverList(
      delegate: SliverChildListDelegate(
        [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
          ),
          if (tasks.isNotEmpty)
            ...tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: GlassContainer(
                  child: TaskCard(
                    task: task,
                    hasConflict: conflictingUuids.contains(task.uuid),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              alignment: Alignment.center,
              child: Text(
                title == "Today"
                    ? "You're all done for today! 🎉"
                    : "No tasks in this category.",
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }
}