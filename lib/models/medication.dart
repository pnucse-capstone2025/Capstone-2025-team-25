class Medication {
  final int id;
  final String nameEn;
  final String nameKr;

  const Medication({
    required this.id,
    required this.nameEn,
    required this.nameKr,
  });

  // A combined name for display in the autocomplete list.
  String get displayName => '$nameEn ($nameKr)';

  // A factory method to create a Medication object from a row in the CSV.
  static Medication fromList(List<dynamic> list) {
    return Medication(
      id: int.tryParse(list[0].toString()) ?? 0,
      nameEn: list[1].toString(),
      nameKr: list[2].toString(),
    );
  }
}
