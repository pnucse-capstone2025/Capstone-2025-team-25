import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../models/medication.dart';

class MedicationService {
  List<Medication> _medications = [];

  Future<void> _loadMedications() async {
    if (_medications.isNotEmpty) return;

    final rawData = await rootBundle.loadString('assets/medications.csv');
    final List<List<dynamic>> listData = const CsvToListConverter(eol: '\n').convert(rawData);
    
    _medications = listData.sublist(1).map((list) => Medication.fromList(list)).toList();
  }

  Future<List<Medication>> getSuggestions(String query) async {
    await _loadMedications(); 

    if (query.isEmpty) {
      return [];
    }
    
    final lowerCaseQuery = query.toLowerCase();
    
    return _medications.where((med) {
      final nameEnLower = med.nameEn.toLowerCase();
      final nameKrLower = med.nameKr.toLowerCase();
      return nameEnLower.contains(lowerCaseQuery) || nameKrLower.contains(lowerCaseQuery);
    }).toList();
  }
}