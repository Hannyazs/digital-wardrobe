import 'peca.dart';

/// Espelha app/schemas/sugestao_de_look.py::SugestaoDeLookRead no backend
/// (E8.F5.2): o look que a IA sugere para uma referência, só com peças do usuário.
class SugestaoDeLook {
  SugestaoDeLook({
    required this.tipo,
    required this.pecas,
    required this.itens,
    required this.lacunas,
    this.look,
  });

  static const tipoLookSalvo = 'look_salvo';
  static const tipoLookNovo = 'look_novo';
  static const tipoSemPecas = 'sem_pecas';

  /// `look_salvo` (um look que já existe contém as peças achadas, em [look]),
  /// `look_novo` (montar um com [pecas]) ou `sem_pecas`.
  final String tipo;
  final LookSalvoSugerido? look;

  /// As peças achadas, sem repetir.
  final List<Peca> pecas;
  final List<ItemDaSugestao> itens;

  /// Etiquetas sem peça equivalente (ou não entendidas).
  final List<String> lacunas;

  /// Etiquetas que não deu tempo de analisar (ficam só em [itens]).
  List<String> get naoAnalisadas =>
      [for (final i in itens) if (i.situacao == ItemDaSugestao.naoAnalisada) i.etiqueta];

  factory SugestaoDeLook.fromJson(Map<String, dynamic> json) {
    final look = json['look'] as Map<String, dynamic>?;
    return SugestaoDeLook(
      tipo: json['tipo'] as String,
      look: look == null ? null : LookSalvoSugerido.fromJson(look),
      pecas: [for (final p in json['pecas'] as List) Peca.fromJson(p as Map<String, dynamic>)],
      itens: [
        for (final i in json['itens'] as List) ItemDaSugestao.fromJson(i as Map<String, dynamic>),
      ],
      lacunas: (json['lacunas'] as List).cast<String>(),
    );
  }
}

class LookSalvoSugerido {
  LookSalvoSugerido({required this.id, required this.nome, required this.pecas});

  final String id;
  final String nome;
  final List<Peca> pecas;

  factory LookSalvoSugerido.fromJson(Map<String, dynamic> json) {
    return LookSalvoSugerido(
      id: json['id'] as String,
      nome: json['nome'] as String,
      pecas: [for (final p in json['pecas'] as List) Peca.fromJson(p as Map<String, dynamic>)],
    );
  }
}

/// O que foi achado para uma etiqueta da referência.
class ItemDaSugestao {
  ItemDaSugestao({
    required this.etiqueta,
    required this.situacao,
    this.peca,
    this.corDiferente = false,
  });

  static const encontrada = 'encontrada';
  static const semPecaEquivalente = 'sem_peca_equivalente';
  static const naoEntendida = 'nao_entendida';
  static const naoAnalisada = 'nao_analisada';

  final String etiqueta;
  final String situacao;
  final Peca? peca;

  /// A peça achada é do tipo da etiqueta, mas de outra cor.
  final bool corDiferente;

  factory ItemDaSugestao.fromJson(Map<String, dynamic> json) {
    final peca = json['peca'] as Map<String, dynamic>?;
    return ItemDaSugestao(
      etiqueta: json['etiqueta'] as String,
      situacao: json['situacao'] as String,
      peca: peca == null ? null : Peca.fromJson(peca),
      corDiferente: json['cor_diferente'] as bool? ?? false,
    );
  }
}
