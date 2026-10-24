/// Espelha app/schemas/colecao.py::ColecaoRead no backend (E8.F2.1).
class Colecao {
  final String id;
  final String nome;

  /// Quantas referências estão na coleção (calculada pelo servidor).
  final int quantidade;
  final DateTime criadoEm;

  Colecao({
    required this.id,
    required this.nome,
    required this.criadoEm,
    this.quantidade = 0,
  });

  factory Colecao.fromJson(Map<String, dynamic> json) {
    return Colecao(
      id: json['id'] as String,
      nome: json['nome'] as String,
      quantidade: json['quantidade'] as int,
      criadoEm: DateTime.parse(json['criado_em'] as String),
    );
  }
}
