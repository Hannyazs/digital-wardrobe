import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// Cliente HTTP compartilhado. O interceptor abaixo injeta o JWT da sessão
/// Supabase em toda requisição autenticada — preencher quando a tela de
/// auth (views/auth/) estiver implementada.
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
          handler.next(options);
        },
      ),
    );
}
