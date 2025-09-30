// lib/services/ddi_service.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class DdiInteraction {
  final int drug1Id;
  final int drug2Id;
  final String level; 

  DdiInteraction({
    required this.drug1Id,
    required this.drug2Id,
    required this.level,
  });

  factory DdiInteraction.fromList(List<dynamic> list) {
    return DdiInteraction(
      drug1Id: int.tryParse(list[0].toString()) ?? 0,
      drug2Id: int.tryParse(list[1].toString()) ?? 0,
      level: list[2].toString(),
    );
  }
}

class DdiService {
  List<DdiInteraction> _interactions = [];

  Future<void> _loadInteractions() async {
    if (_interactions.isNotEmpty) return;

    final rawData = await rootBundle.loadString('assets/ddi.csv');
    final List<List<dynamic>> listData = const CsvToListConverter(
      eol: '\n',
    ).convert(rawData);

    _interactions = listData
        .sublist(1)
        .map((list) => DdiInteraction.fromList(list))
        .toList();
  }

  Future<Map<int, String>> findInteractions(
    int newMedicationId,
    List<int> existingMedicationIds,
  ) async {
    await _loadInteractions();
    final Map<int, String> conflicts = {};

    for (final interaction in _interactions) {
      if (interaction.drug1Id == newMedicationId &&
          existingMedicationIds.contains(interaction.drug2Id)) {
        conflicts[interaction.drug2Id] = interaction.level;
      } else if (interaction.drug2Id == newMedicationId &&
          existingMedicationIds.contains(interaction.drug1Id)) {
        conflicts[interaction.drug1Id] = interaction.level;
      }
    }
    return conflicts;
  }

  Future<String?> getInteractionLevel(int medId1, int medId2) async {
    await _loadInteractions();
    for (final interaction in _interactions) {
      if ((interaction.drug1Id == medId1 && interaction.drug2Id == medId2) ||
          (interaction.drug1Id == medId2 && interaction.drug2Id == medId1)) {
        return interaction.level;
      }
    }
    return null;
  }
}
