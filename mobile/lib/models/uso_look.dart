import 'look.dart';

/// Espelha app/schemas/look.py::UsoLookRead no backend (E3.F4.1).
class UsoLook {
  final String id;
  final String lookId;

  /// Só o dia. `DateTime.parse('yyyy-MM-dd')` interpreta como meia-noite no
  /// horário local, que é o que queremos para rótulos como "Hoje".
  final DateTime usadoEm;
  final Look look;

  UsoLook({required this.id, required this.lookId, required this.usadoEm, required this.look});

  factory UsoLook.fromJson(Map<String, dynamic> json) {
    return UsoLook(
      id: json['id'] as String,
      lookId: json['look_id'] as String,
      usadoEm: DateTime.parse(json['usado_em'] as String),
      look: Look.fromJson(json['look'] as Map<String, dynamic>),
    );
  }
}
