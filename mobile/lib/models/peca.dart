import '../core/constants/peca_opcoes.dart' show coresFixas;

/// Campos que deixam a peça com cadastro incompleto (E5.F4.1), na ordem
/// "cor", "ocasião", "estilo". Mesma regra do motor de sugestões
/// (`backend/.../montagem.py::campos_incompletos`, regras-sugestoes.md seção 4):
/// cor vazia ou fora da lista fixa conta como "sem cor"; estação não conta.
List<String> camposIncompletos(Peca peca) {
  final cor = peca.corPrincipal?.trim() ?? '';
  return [
    if (!coresFixas.any((c) => c.nome == cor)) 'cor',
    if (peca.ocasioes.every((o) => o.trim().isEmpty)) 'ocasião',
    if ((peca.estilo?.trim() ?? '').isEmpty) 'estilo',
  ];
}

/// Espelha app/schemas/peca.py::PecaRead no backend.
class Peca {
  final String id;
  final String imagemUrl;
  final String categoria;
  final String? subcategoria;
  final String? corPrincipal;
  final String? tonalidadeCor;
  final String? estacao;
  final String? estilo;
  final String? modelagem;
  final List<String> ocasioes;

  Peca({
    required this.id,
    required this.imagemUrl,
    required this.categoria,
    this.subcategoria,
    this.corPrincipal,
    this.tonalidadeCor,
    this.estacao,
    this.estilo,
    this.modelagem,
    this.ocasioes = const [],
  });

  factory Peca.fromJson(Map<String, dynamic> json) {
    return Peca(
      id: json['id'] as String,
      imagemUrl: json['imagem_url'] as String,
      categoria: json['categoria'] as String,
      subcategoria: json['subcategoria'] as String?,
      corPrincipal: json['cor_principal'] as String?,
      tonalidadeCor: json['tonalidade_cor'] as String?,
      estacao: json['estacao'] as String?,
      estilo: json['estilo'] as String?,
      modelagem: json['modelagem'] as String?,
      ocasioes: (json['ocasioes'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imagem_url': imagemUrl,
      'categoria': categoria,
      'subcategoria': subcategoria,
      'cor_principal': corPrincipal,
      'tonalidade_cor': tonalidadeCor,
      'estacao': estacao,
      'estilo': estilo,
      'modelagem': modelagem,
      'ocasioes': ocasioes,
    };
  }
}
