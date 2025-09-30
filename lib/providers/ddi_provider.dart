// lib/providers/ddi_provider.dart
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/medication.dart';
import '../services/ddi_service.dart';

class DdiProvider with ChangeNotifier {
  final DdiService _ddiService = DdiService();

  Map<String, String> _newMedicationConflicts = {};
  bool _isLoading = false;

  Map<String, String> get newMedicationConflicts => _newMedicationConflicts;
  bool get isLoading => _isLoading;

  Future<void> checkForNewMedication(Medication newMed, List<AppTask> existingTasks) async {
    _isLoading = true;
    _newMedicationConflicts = {};
    notifyListeners();

    final existingMedicationIds = existingTasks
        .where((task) => task.isMedication && task.medicationId != null)
        .map((task) => task.medicationId!)
        .toList();

    if (existingMedicationIds.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    final interactions = await _ddiService.findInteractions(newMed.id, existingMedicationIds);

    if (interactions.isNotEmpty) {
      for (final entry in interactions.entries) {
        final conflictingMedId = entry.key;
        final interactionLevel = entry.value;

        final conflictingTask = existingTasks.firstWhere(
            (task) => task.medicationId == conflictingMedId,
        );
        _newMedicationConflicts[conflictingTask.name] = interactionLevel;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearConflicts() {
    _newMedicationConflicts = {};
    notifyListeners();
  }
}