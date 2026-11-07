import 'peca.dart';

/// Espelha app/schemas/look.py::LookRead no backend.
class Look {
  final String id;
  final String nome;
  final DateTime criadoEm;
  final List<Peca> pecas;
  final bool favorito;

  /// Um look pode servir a várias ocasiões (backend, migração 0008).
  final List<String> ocasioes;

  /// Pasta do look (E3.F6.1); `null` = "Sem pasta".
  final String? pastaId;

  Look({
    required this.id,
    required this.nome,
    required this.criadoEm,
    required this.pecas,
    this.favorito = false,
    this.ocasioes = const [],
    this.pastaId,
  });

  factory Look.fromJson(Map<String, dynamic> json) {
    return Look(
      id: json['id'] as String,
      nome: json['nome'] as String,
      criadoEm: DateTime.parse(json['criado_em'] as String),
      pecas: (json['pecas'] as List)
          .map((peca) => Peca.fromJson(peca as Map<String, dynamic>))
          .toList(),
      favorito: json['favorito'] as bool? ?? false,
      ocasioes: ((json['ocasioes'] as List?) ?? const []).map((o) => o as String).toList(),
      pastaId: json['pasta_id'] as String?,
    );
  }
}
