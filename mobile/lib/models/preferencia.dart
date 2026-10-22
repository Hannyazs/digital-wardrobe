/// Par de cores que o usuário gosta de ver juntas (E4.F1.1). Sem ordem:
/// (Azul, Branco) e (Branco, Azul) são o mesmo par.
class CombinacaoCores {
  const CombinacaoCores(this.corA, this.corB);

  final String corA;
  final String corB;

  factory CombinacaoCores.fromJson(Map<String, dynamic> json) =>
      CombinacaoCores(json['cor_a'] as String, json['cor_b'] as String);

  Map<String, dynamic> toJson() => {'cor_a': corA, 'cor_b': corB};

  /// Igualdade ignorando a ordem das cores.
  bool mesmoPar(CombinacaoCores outra) =>
      (corA == outra.corA && corB == outra.corB) || (corA == outra.corB && corB == outra.corA);
}

/// Espelha app/schemas/preferencia.py::PreferenciaRead no backend (E4.F1.1).
/// Já inclui `estilos`, `sobreposicoes` e `criatividade`, usados pelas seções
/// das E4.F2, E4.F3 e E4.F5, para elas não precisarem mexer no modelo.
class Preferencia {
  const Preferencia({
    this.estilos = const [],
    this.sobreposicoes = const [],
    this.combinacoesCores = const [],
    this.criatividade = 3,
    this.ocasiaoLookDoDia,
  });

  final List<String> estilos;
  final List<String> sobreposicoes;
  final List<CombinacaoCores> combinacoesCores;
  final int criatividade;

  /// Ocasião escolhida no card "Look do dia" (E6.F1.2); `null` = nunca
  /// escolhida (o backend usa "Casual").
  final String? ocasiaoLookDoDia;

  /// Tolera chaves ausentes (usa os padrões do backend: listas vazias, nível 3).
  factory Preferencia.fromJson(Map<String, dynamic> json) {
    return Preferencia(
      estilos: _lista(json['estilos']),
      sobreposicoes: _lista(json['sobreposicoes']),
      combinacoesCores: ((json['combinacoes_cores'] as List?) ?? const [])
          .map((par) => CombinacaoCores.fromJson(par as Map<String, dynamic>))
          .toList(),
      criatividade: json['criatividade'] as int? ?? 3,
      ocasiaoLookDoDia: json['ocasiao_look_do_dia'] as String?,
    );
  }

  static List<String> _lista(Object? valor) =>
      ((valor as List?) ?? const []).map((item) => item as String).toList();

  Preferencia copyWith({
    List<String>? estilos,
    List<String>? sobreposicoes,
    List<CombinacaoCores>? combinacoesCores,
    int? criatividade,
    String? ocasiaoLookDoDia,
  }) {
    return Preferencia(
      estilos: estilos ?? this.estilos,
      sobreposicoes: sobreposicoes ?? this.sobreposicoes,
      combinacoesCores: combinacoesCores ?? this.combinacoesCores,
      criatividade: criatividade ?? this.criatividade,
      ocasiaoLookDoDia: ocasiaoLookDoDia ?? this.ocasiaoLookDoDia,
    );
  }
}
