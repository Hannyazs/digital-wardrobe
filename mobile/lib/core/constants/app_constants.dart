class AppConstants {
  AppConstants._();

  // TODO: mover para variável de ambiente (--dart-define) antes de builds de produção.
  static const String apiBaseUrl = 'http://localhost:8000/api/v1';

  // Origem do backend sem o prefixo /api/v1 — usada para resolver URLs de
  // mídia (ex: imagem_url = "/uploads/xxx.png") retornadas como caminho
  // relativo. Sem isso, Image.network resolveria contra a origem do próprio
  // app Flutter Web, não a da API.
  static const String apiOrigin = 'http://localhost:8000';

  static String resolveMediaUrl(String imagemUrl) {
    if (imagemUrl.startsWith('http://') || imagemUrl.startsWith('https://')) {
      return imagemUrl;
    }
    return '$apiOrigin$imagemUrl';
  }
}
