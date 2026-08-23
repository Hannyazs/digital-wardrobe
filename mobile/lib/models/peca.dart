/// Espelha app/schemas/peca.py::PecaRead no backend.
class Peca {
  final String id;
  final String imagemUrl;
  final String categoria;
  final String? subcategoria;
  final String? corPrincipal;
  final String? estacao;
  final String? ocasiao;

  Peca({
    required this.id,
    required this.imagemUrl,
    required this.categoria,
    this.subcategoria,
    this.corPrincipal,
    this.estacao,
    this.ocasiao,
  });

  factory Peca.fromJson(Map<String, dynamic> json) {
    return Peca(
      id: json['id'] as String,
      imagemUrl: json['imagem_url'] as String,
      categoria: json['categoria'] as String,
      subcategoria: json['subcategoria'] as String?,
      corPrincipal: json['cor_principal'] as String?,
      estacao: json['estacao'] as String?,
      ocasiao: json['ocasiao'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imagem_url': imagemUrl,
      'categoria': categoria,
      'subcategoria': subcategoria,
      'cor_principal': corPrincipal,
      'estacao': estacao,
      'ocasiao': ocasiao,
    };
  }
}
