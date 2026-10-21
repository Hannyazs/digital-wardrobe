import 'peca.dart';

/// Par de peças que o usuário não quer ver juntas (E4.F4.1). As peças vêm
/// na ordem gravada pelo backend, não na ordem em que foram escolhidas.
class CombinacaoEvitada {
  const CombinacaoEvitada({required this.id, required this.pecas});

  final String id;
  final List<Peca> pecas;

  factory CombinacaoEvitada.fromJson(Map<String, dynamic> json) => CombinacaoEvitada(
        id: json['id'] as String,
        pecas: (json['pecas'] as List)
            .map((peca) => Peca.fromJson(peca as Map<String, dynamic>))
            .toList(),
      );
}

/// Espelha app/schemas/preferencia.py::EvitadasRead (E4.F4.1): peças e pares
/// de peças que as sugestões (Épico 6) nunca devem usar. Já traz as
/// combinações, para a E4.F4.3 não mexer no modelo.
class Evitadas {
  const Evitadas({this.pecas = const [], this.combinacoes = const []});

  final List<Peca> pecas;
  final List<CombinacaoEvitada> combinacoes;

  bool contemPeca(String pecaId) => pecas.any((peca) => peca.id == pecaId);

  factory Evitadas.fromJson(Map<String, dynamic> json) => Evitadas(
        pecas: ((json['pecas'] as List?) ?? const [])
            .map((peca) => Peca.fromJson(peca as Map<String, dynamic>))
            .toList(),
        combinacoes: ((json['combinacoes'] as List?) ?? const [])
            .map((par) => CombinacaoEvitada.fromJson(par as Map<String, dynamic>))
            .toList(),
      );
}
