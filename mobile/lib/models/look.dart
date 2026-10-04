import 'peca.dart';

/// Espelha app/schemas/look.py::LookRead no backend.
class Look {
  final String id;
  final String nome;
  final DateTime criadoEm;
  final List<Peca> pecas;

  Look({
    required this.id,
    required this.nome,
    required this.criadoEm,
    required this.pecas,
  });

  factory Look.fromJson(Map<String, dynamic> json) {
    return Look(
      id: json['id'] as String,
      nome: json['nome'] as String,
      criadoEm: DateTime.parse(json['criado_em'] as String),
      pecas: (json['pecas'] as List)
          .map((peca) => Peca.fromJson(peca as Map<String, dynamic>))
          .toList(),
    );
  }
}
