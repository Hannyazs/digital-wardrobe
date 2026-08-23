import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// Cliente HTTP compartilhado. O interceptor abaixo injeta o JWT da sessão
/// Supabase em toda requisição autenticada — preencher quando a tela de
/// auth (views/auth/) estiver implementada.
class ApiClient {
  ApiClient._();

  static final Dio instance = Dio(
    BaseOptions(baseUrl: AppConstants.apiBaseUrl),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // TODO: options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          handler.next(options);
        },
      ),
    );
}
