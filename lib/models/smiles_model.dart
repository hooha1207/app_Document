class SmilesData {
  final String koName;
  final String enName;
  final String formula;
  final String smiles;

  SmilesData({
    required this.koName,
    required this.enName,
    required this.formula,
    required this.smiles,
  });

  factory SmilesData.fromJson(Map<String, dynamic> json) {
    return SmilesData(
      koName: json['koName'] ?? '',
      enName: json['enName'] ?? '',
      formula: json['formula'] ?? '',
      smiles: json['smiles'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'koName': koName,
      'enName': enName,
      'formula': formula,
      'smiles': smiles,
    };
  }
}
