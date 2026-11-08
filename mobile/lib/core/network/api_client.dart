import 'package:dio/dio.dart';

import '../auth/auth_service.dart';
import '../constants/app_constants.dart';
import 'auth_interceptor.dart';

/// Cliente HTTP compartilhado por todos os services. O token do usuário
/// logado entra pelo [AuthInterceptor], ligado em [usarConta] pelo `main.dart`
/// (E9.F2.2). Nos testes os services são falsos e nada disso é usado.
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
  );

  /// Liga o token da conta às chamadas da API (substitui uma ligação anterior).
  static void usarConta(AuthService auth) {
    instance.interceptors.removeWhere((i) => i is AuthInterceptor);
    instance.interceptors.add(AuthInterceptor(auth, instance));
  }
}
