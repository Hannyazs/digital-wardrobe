/// O look a que uma referência está ligada (E8.F3.1): só id e nome; as peças
/// vêm da lista de looks do app.
class ReferenciaLook {
  final String id;
  final String nome;

  ReferenciaLook({required this.id, required this.nome});

  factory ReferenciaLook.fromJson(Map<String, dynamic> json) {
    return ReferenciaLook(id: json['id'] as String, nome: json['nome'] as String);
  }
}

/// Espelha app/schemas/referencia.py::ReferenciaRead no backend (E8.F1.1).
class Referencia {
  final String id;
  final String imagemUrl;
  final String? nota;

  /// Coleção da referência (E8.F2); `null` = "Sem coleção".
  final String? colecaoId;

  /// Look salvo ao qual a referência está ligada (E8.F3); `null` = nenhum (o
  /// servidor também devolve `null` se o look foi arquivado).
  final ReferenciaLook? look;

  /// Peças visíveis na imagem, sugeridas pela IA e editáveis (E8.F4).
  final List<String> etiquetas;
  final DateTime criadoEm;

  Referencia({
    required this.id,
    required this.imagemUrl,
    required this.criadoEm,
    this.nota,
    this.colecaoId,
    this.look,
    this.etiquetas = const [],
  });

  factory Referencia.fromJson(Map<String, dynamic> json) {
    final look = json['look'] as Map<String, dynamic>?;
    return Referencia(
      id: json['id'] as String,
      imagemUrl: json['imagem_url'] as String,
      nota: json['nota'] as String?,
      colecaoId: json['colecao_id'] as String?,
      look: look == null ? null : ReferenciaLook.fromJson(look),
      etiquetas: (json['etiquetas'] as List?)?.cast<String>() ?? const [],
      criadoEm: DateTime.parse(json['criado_em'] as String),
    );
  }

  /// A mesma referência, fora de qualquer coleção.
  Referencia semColecao() => Referencia(
        id: id,
        imagemUrl: imagemUrl,
        nota: nota,
        look: look,
        etiquetas: etiquetas,
        criadoEm: criadoEm,
      );
}
