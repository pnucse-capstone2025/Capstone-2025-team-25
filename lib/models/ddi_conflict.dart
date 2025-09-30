// lib/models/ddi_conflict.dart

class DdiConflict {
  final String taskUuid1;
  final String taskName1;
  final String taskUuid2;
  final String taskName2;
  final String level;

  DdiConflict({
    required this.taskUuid1,
    required this.taskName1,
    required this.taskUuid2,
    required this.taskName2,
    required this.level,
  });
}