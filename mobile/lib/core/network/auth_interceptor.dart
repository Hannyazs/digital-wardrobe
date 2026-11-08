import 'package:dio/dio.dart';

import '../auth/auth_service.dart';

/// Põe o token do usuário logado em toda chamada à API e trata o token
/// vencido (E9.F2.2).
///
/// - Antes de cada requisição: usa o token da sessão atual (renovado antes, se
///   já venceu).
/// - Resposta 401: renova o token e repete a requisição **uma** vez. Se outra
///   requisição já renovou nesse meio-tempo, só repete com o token novo.
/// - 401 de novo, ou renovação impossível: encerra a sessão e o app volta ao
///   login com o aviso "sessão expirada".
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._auth, this._dio);

  final AuthService _auth;
  final Dio _dio;

  static const _jaRepetida = 'auth_repetida';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _auth.tokenDeAcesso();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final pedido = err.requestOptions;
    final tinhaToken = pedido.headers['Authorization'] != null;
    if (err.response?.statusCode != 401 || !tinhaToken || pedido.extra[_jaRepetida] == true) {
      if (err.response?.statusCode == 401 && pedido.extra[_jaRepetida] == true) {
        await _auth.encerrarSessaoExpirada();
      }
      handler.next(err);
      return;
    }

    final usado = (pedido.headers['Authorization'] as String).replaceFirst('Bearer ', '');
    final atual = await _auth.tokenDeAcesso();
    final novo = (atual != null && atual != usado) ? atual : await _auth.renovarToken();
    if (novo == null) {
      await _auth.encerrarSessaoExpirada();
      handler.next(err);
      return;
    }

    final dados = pedido.data;
    final repeticao = pedido.copyWith(
      // Um FormData já enviado não pode ser lido de novo: vai uma cópia.
      data: dados is FormData ? dados.clone() : dados,
      headers: {...pedido.headers, 'Authorization': 'Bearer $novo'},
      extra: {...pedido.extra, _jaRepetida: true},
    );
    try {
      handler.resolve(await _dio.fetch<dynamic>(repeticao));
    } on DioException catch (erro) {
      // O 401 da repetição já passou por este interceptor e encerrou a sessão.
      handler.next(erro);
    }
  }
}
