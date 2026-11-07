/// Espelha app/schemas/pasta.py::PastaRead no backend (E3.F6.1).
class PastaLook {
  final String id;
  final String nome;

  /// Quantos looks não arquivados estão na pasta (calculada pelo servidor).
  final int quantidade;
  final DateTime criadoEm;

  PastaLook({
    required this.id,
    required this.nome,
    required this.criadoEm,
    this.quantidade = 0,
  });

  factory PastaLook.fromJson(Map<String, dynamic> json) {
    return PastaLook(
      id: json['id'] as String,
      nome: json['nome'] as String,
      quantidade: json['quantidade'] as int,
      criadoEm: DateTime.parse(json['criado_em'] as String),
    );
  }
}
