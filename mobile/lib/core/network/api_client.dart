import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// Token de desenvolvimento opcional, gerado por
/// `backend/scripts/gerar_token_teste.py` e passado via
/// `--dart-define=DEV_AUTH_TOKEN=<token>` (ver README.md, seção "Testando
/// endpoints autenticados"). Só serve para destravar telas que já exigem
/// JWT (E1.F2.1) antes de existir login real via Supabase — nunca usar em
/// produção.
const _devAuthToken = String.fromEnvironment('DEV_AUTH_TOKEN');

/// Cliente HTTP compartilhado. O interceptor abaixo injeta o JWT da sessão
/// Supabase em toda requisição autenticada — substituir pelo token da
/// sessão real quando a tela de auth (views/auth/) estiver implementada.
class ApiClient {
  ApiClient._();

  static final Dio instance = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      // 60s, não menos: a primeira chamada a /pecas/processar-imagem baixa
      // o modelo do rembg (~176MB) no backend e é bem mais lenta que as
      // seguintes — ver E1.F1.2 e E1.F1.3.
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // TODO: options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          if (_devAuthToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_devAuthToken';
          }
          handler.next(options);
        },
      ),
    );
}
