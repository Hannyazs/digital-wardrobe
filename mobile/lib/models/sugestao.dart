import 'peca.dart';

/// Um look sugerido. Espelha app/schemas/sugestao.py::LookSugeridoRead (E5.F1.2).
class Sugestao {
  const Sugestao({required this.pecas, this.explicacoes = const [], this.avisos = const []});

  final List<Peca> pecas;
  final List<String> explicacoes;
  final List<String> avisos;

  /// Ids das peças: identificam o look nos descartes da sessão.
  List<String> get pecaIds => pecas.map((p) => p.id).toList();

  /// Chave estável (ids ordenados) para comparar looks entre páginas.
  String get chave => ([...pecaIds]..sort()).join(',');

  factory Sugestao.fromJson(Map<String, dynamic> json) {
    return Sugestao(
      pecas: (json['pecas'] as List)
          .map((p) => Peca.fromJson(p as Map<String, dynamic>))
          .toList(),
      explicacoes: _textos(json['explicacoes']),
      avisos: _textos(json['avisos']),
    );
  }
}

/// Peça-base com valor diferente de um filtro ativo (usado a partir da E5.F2.2).
class ConflitoSugestao {
  const ConflitoSugestao({
    required this.filtro,
    required this.valorFiltro,
    required this.valorPeca,
    required this.mensagem,
  });

  final String filtro;
  final String valorFiltro;
  final String valorPeca;
  final String mensagem;

  factory ConflitoSugestao.fromJson(Map<String, dynamic> json) {
    return ConflitoSugestao(
      filtro: json['filtro'] as String,
      valorFiltro: json['valor_filtro'] as String,
      valorPeca: json['valor_peca'] as String,
      mensagem: json['mensagem'] as String,
    );
  }
}

/// Espelha app/schemas/sugestao.py::SugestoesRead.
class PaginaSugestoes {
  const PaginaSugestoes({
    this.looks = const [],
    this.pagina = 1,
    this.temMais = false,
    this.motivo,
    this.conflitos = const [],
  });

  final List<Sugestao> looks;
  final int pagina;
  final bool temMais;
  final String? motivo;
  final List<ConflitoSugestao> conflitos;

  factory PaginaSugestoes.fromJson(Map<String, dynamic> json) {
    return PaginaSugestoes(
      looks: (json['looks'] as List)
          .map((l) => Sugestao.fromJson(l as Map<String, dynamic>))
          .toList(),
      pagina: json['pagina'] as int,
      temMais: json['tem_mais'] as bool,
      motivo: json['motivo'] as String?,
      conflitos: ((json['conflitos'] as List?) ?? const [])
          .map((c) => ConflitoSugestao.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Espelha app/schemas/sugestao.py::LookDoDiaRead (E6.F1.1). [look] é `null`
/// quando não há look possível (armário insuficiente ou tudo descartado) —
/// aí [motivo] explica.
class LookDoDia {
  const LookDoDia({this.look, required this.ocasiao, this.temMais = false, this.motivo});

  final Sugestao? look;

  /// Ocasião usada pelo backend: a pedida, senão a salva, senão "Casual".
  final String ocasiao;
  final bool temMais;
  final String? motivo;

  factory LookDoDia.fromJson(Map<String, dynamic> json) {
    final look = json['look'];
    return LookDoDia(
      look: look == null ? null : Sugestao.fromJson(look as Map<String, dynamic>),
      ocasiao: json['ocasiao'] as String,
      temMais: json['tem_mais'] as bool? ?? false,
      motivo: json['motivo'] as String?,
    );
  }
}

List<String> _textos(Object? valor) =>
    ((valor as List?) ?? const []).map((t) => t as String).toList();
