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
    if (peca.estilos.every((e) => e.trim().isEmpty)) 'estilo',
  ];
}

/// Todas as cores da peça: a predominante e as secundárias (multicolorida).
List<String> coresDaPeca(Peca peca) => [
      if (peca.corPrincipal?.trim().isNotEmpty ?? false) peca.corPrincipal!.trim(),
      ...peca.coresSecundarias,
    ];

/// Descrição curta da peça para leitores de tela: "Calças, jeans, preto".
String descricaoPeca(Peca peca) => [
      peca.categoria,
      if (peca.subcategoria?.trim().isNotEmpty ?? false) peca.subcategoria!.trim(),
      if (peca.corPrincipal?.trim().isNotEmpty ?? false) peca.corPrincipal!.trim().toLowerCase(),
    ].join(', ');

/// Espelha app/schemas/peca.py::PecaRead no backend.
class Peca {
  final String id;
  final String imagemUrl;
  final String categoria;
  final String? subcategoria;
  final String? corPrincipal;
  final String? tonalidadeCor;
  final List<String> estacoes;

  /// Peça multicolorida: as demais cores; a predominante é [corPrincipal].
  final List<String> coresSecundarias;
  final List<String> estilos;
  final String? modelagem;
  final List<String> ocasioes;

  Peca({
    required this.id,
    required this.imagemUrl,
    required this.categoria,
    this.subcategoria,
    this.corPrincipal,
    this.tonalidadeCor,
    this.estacoes = const [],
    this.coresSecundarias = const [],
    this.estilos = const [],
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
      estacoes: (json['estacoes'] as List?)?.cast<String>() ?? const [],
      coresSecundarias: (json['cores_secundarias'] as List?)?.cast<String>() ?? const [],
      estilos: (json['estilos'] as List?)?.cast<String>() ?? const [],
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
      'estacoes': estacoes,
      'cores_secundarias': coresSecundarias,
      'estilos': estilos,
      'modelagem': modelagem,
      'ocasioes': ocasioes,
    };
  }
}
