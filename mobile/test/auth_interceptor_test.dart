// Token real nas chamadas à API, renovação e sessão expirada (E9.F2.2).
// O "servidor" é um adaptador falso do Dio: nada sai da máquina.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/core/auth/auth_service.dart';
import 'package:guarda_roupa_app/core/network/auth_interceptor.dart';

import 'support/auth_service_falso.dart';

/// API falsa: responde 200 só para o token que ela considera válido (por
/// padrão, o token atual da conta falsa) e 401 para o resto.
class _ApiFalsa implements HttpClientAdapter {
  _ApiFalsa(this.valido);

  /// Decide se o cabeçalho `Authorization` recebido é aceito.
  bool Function(String? authorization) valido;

  final recebidos = <({String caminho, String? authorization, String? corpo})>[];

  /// Segura as respostas até o teste liberar (para simular chamadas simultâneas).
  Completer<void>? segurar;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    String? corpo;
    if (requestStream != null) {
      corpo = utf8.decode(await requestStream.expand((b) => b).toList(), allowMalformed: true);
    }
    final authorization = options.headers['Authorization'] as String?;
    recebidos.add((caminho: options.path, authorization: authorization, corpo: corpo));
    if (segurar != null) await segurar!.future;
    if (!valido(authorization)) {
      return ResponseBody.fromString('{"detail":"Token inválido ou expirado."}', 401,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    return ResponseBody.fromString('{"ok":true}', 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

({Dio dio, _ApiFalsa api}) _cliente(AuthService auth, bool Function(String?) valido) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.teste'));
  final api = _ApiFalsa(valido);
  dio.httpClientAdapter = api;
  dio.interceptors.add(AuthInterceptor(auth, dio));
  return (dio: dio, api: api);
}

void main() {
  test('sessão válida: a requisição vai com o token do usuário logado', () async {
    final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com');
    final c = _cliente(auth, (a) => a == 'Bearer ${auth.tokenAtual}');

    final resposta = await c.dio.get<dynamic>('/pecas');

    expect(resposta.statusCode, 200);
    expect(c.api.recebidos.single.authorization, 'Bearer token-ana@exemplo.com-v1');
    expect(auth.renovacoes, 0);
  });

  test('sem sessão: a requisição vai sem token e o 401 não tenta renovar', () async {
    final auth = AuthServiceFalso();
    final c = _cliente(auth, (a) => a != null);

    await expectLater(c.dio.get<dynamic>('/pecas'), throwsA(isA<DioException>()));
    expect(c.api.recebidos.single.authorization, isNull);
    expect(auth.renovacoes, 0);
    expect(auth.expiracoes, 0);
  });

  test('token vencido: renova e repete a requisição uma vez', () async {
    final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com');
    // O servidor já não aceita a v1 (venceu); aceita a v2.
    final c = _cliente(auth, (a) => a == 'Bearer token-ana@exemplo.com-v2');

    final resposta = await c.dio.get<dynamic>('/pecas');

    expect(resposta.statusCode, 200);
    expect(c.api.recebidos.map((r) => r.authorization), [
      'Bearer token-ana@exemplo.com-v1',
      'Bearer token-ana@exemplo.com-v2',
    ]);
    expect(auth.renovacoes, 1);
    expect(auth.usuarioId, isNotNull);
  });

  test('renovação impossível: encerra a sessão com aviso de sessão expirada', () async {
    final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com')..renovacaoFalha = true;
    final c = _cliente(auth, (_) => false);

    await expectLater(
      c.dio.get<dynamic>('/pecas'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 401)),
    );
    expect(c.api.recebidos, hasLength(1)); // não repete sem token novo
    expect(auth.usuarioId, isNull);
    expect(auth.estado.aviso?.tipo, TipoDeAviso.sessaoExpirada);
    expect(auth.estado.aviso?.mensagem, 'Sua sessão expirou. Entre de novo.');
  });

  test('401 que persiste depois de renovar: uma única repetição e volta ao login', () async {
    final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com');
    final c = _cliente(auth, (_) => false);

    await expectLater(c.dio.get<dynamic>('/pecas'), throwsA(isA<DioException>()));

    expect(c.api.recebidos, hasLength(2)); // original + uma repetição, sem laço
    expect(auth.renovacoes, 1);
    expect(auth.expiracoes, 1);
    expect(auth.usuarioId, isNull);
  });

  test('outros erros (404, 500) não mexem na sessão', () async {
    final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com');
    final dio = Dio(BaseOptions(baseUrl: 'http://api.teste'));
    dio.httpClientAdapter = _ApiFalsa((_) => true);
    dio.interceptors.add(AuthInterceptor(auth, dio));
    dio.interceptors.add(InterceptorsWrapper(onResponse: (r, h) {
      h.reject(DioException(requestOptions: r.requestOptions, response: Response(
        requestOptions: r.requestOptions, statusCode: 500)));
    }));

    await expectLater(dio.get<dynamic>('/pecas'), throwsA(isA<DioException>()));
    expect(auth.renovacoes, 0);
    expect(auth.usuarioId, isNotNull);
  });

  test('requisições simultâneas com token vencido: uma renovação só', () async {
    final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com');
    final c = _cliente(auth, (a) => a == 'Bearer ${auth.tokenAtual}' && auth.tokenAtual!.endsWith('-v2'));
    c.api.segurar = Completer<void>();

    final pedidos = [c.dio.get<dynamic>('/pecas'), c.dio.get<dynamic>('/looks'), c.dio.get<dynamic>('/pastas')];
    await Future<void>.delayed(Duration.zero);
    c.api.segurar!.complete();
    c.api.segurar = null;
    final respostas = await Future.wait(pedidos);

    expect(respostas.map((r) => r.statusCode), [200, 200, 200]);
    // A primeira renova; as outras percebem o token novo e só repetem.
    expect(auth.renovacoes, 1);
    expect(auth.usuarioId, isNotNull);
  });

  test('envio de foto (FormData) também é repetido depois de renovar', () async {
    final auth = AuthServiceFalso(logadoComo: 'ana@exemplo.com');
    final c = _cliente(auth, (a) => a == 'Bearer token-ana@exemplo.com-v2');

    final resposta = await c.dio.post<dynamic>(
      '/referencias',
      data: FormData.fromMap({'imagem': MultipartFile.fromBytes([1, 2, 3], filename: 'foto.png')}),
    );

    expect(resposta.statusCode, 200);
    expect(c.api.recebidos, hasLength(2));
    expect(c.api.recebidos.last.corpo, contains('foto.png'));
  });
}
