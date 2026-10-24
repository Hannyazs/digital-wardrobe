// "Ligar a um look": manual ou automático (E8.F5.3). Serviços falsos, nunca bate
// numa API real; a IA é simulada pelo `sugerirLook` do serviço falso.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guarda_roupa_app/core/network/api_client.dart';
import 'package:guarda_roupa_app/models/colecao.dart';
import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/models/referencia.dart';
import 'package:guarda_roupa_app/models/sugestao_de_look.dart';
import 'package:guarda_roupa_app/services/colecao_service.dart';
import 'package:guarda_roupa_app/services/referencia_service.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/references/references_controller.dart';
import 'package:guarda_roupa_app/views/references/sugestao_de_look_view.dart';
import 'package:guarda_roupa_app/views/references/widgets/referencia_detalhe.dart';

import 'support/look_service_sem_historico.dart';

Peca _peca(String id, String categoria, {String? sub, String? cor}) => Peca(
      id: id,
      imagemUrl: '/uploads/$id.png',
      categoria: categoria,
      subcategoria: sub,
      corPrincipal: cor,
    );

final _calca = _peca('calca', 'Calças', sub: 'jeans', cor: 'Azul');
final _tenis = _peca('tenis', 'Sapatos', cor: 'Branco');

SugestaoDeLook _novo({List<String> lacunas = const [], List<ItemDaSugestao> extras = const []}) =>
    SugestaoDeLook(
      tipo: SugestaoDeLook.tipoLookNovo,
      pecas: [_calca, _tenis],
      itens: [
        ItemDaSugestao(etiqueta: 'calça jeans azul', situacao: ItemDaSugestao.encontrada, peca: _calca),
        ItemDaSugestao(etiqueta: 'tênis branco', situacao: ItemDaSugestao.encontrada, peca: _tenis),
        for (final l in lacunas) ItemDaSugestao(etiqueta: l, situacao: ItemDaSugestao.semPecaEquivalente),
        ...extras,
      ],
      lacunas: lacunas,
    );

SugestaoDeLook _salvo() => SugestaoDeLook(
      tipo: SugestaoDeLook.tipoLookSalvo,
      look: LookSalvoSugerido(id: 'look-1', nome: 'Look de sexta', pecas: [_calca, _tenis]),
      pecas: [_calca, _tenis],
      itens: [
        ItemDaSugestao(etiqueta: 'calça jeans azul', situacao: ItemDaSugestao.encontrada, peca: _calca),
        ItemDaSugestao(etiqueta: 'tênis branco', situacao: ItemDaSugestao.encontrada, peca: _tenis),
      ],
      lacunas: const [],
    );

SugestaoDeLook _semPecas() => SugestaoDeLook(
      tipo: SugestaoDeLook.tipoSemPecas,
      pecas: const [],
      itens: [
        ItemDaSugestao(etiqueta: 'cinto preto', situacao: ItemDaSugestao.semPecaEquivalente),
        ItemDaSugestao(etiqueta: 'coisa estranha', situacao: ItemDaSugestao.naoEntendida),
      ],
      lacunas: const ['cinto preto', 'coisa estranha'],
    );

DioException _erro(int? status, {Object? corpo, DioExceptionType tipo = DioExceptionType.badResponse}) =>
    DioException(
      requestOptions: RequestOptions(path: '/referencias/a/sugestao-de-look'),
      type: tipo,
      response: status == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: status,
              data: corpo,
            ),
    );

class _ReferenciaServiceFalso extends ReferenciaService {
  _ReferenciaServiceFalso({List<String> etiquetas = const ['calça jeans azul'], String? nota})
      : banco = [
          Referencia(
            id: 'a',
            imagemUrl: '/uploads/a.jpg',
            nota: nota,
            etiquetas: etiquetas,
            criadoEm: DateTime(2026, 10, 23),
          ),
        ];

  final List<Referencia> banco;
  final ligacoes = <String?>[];
  int pedidos = 0;

  /// O que `sugerirLook` faz a cada pedido (o último se acabarem).
  final respostas = <FutureOr<SugestaoDeLook> Function()>[];
  Object? falhaAoLigar;

  @override
  Future<List<Referencia>> listar() async => [...banco];

  @override
  Future<SugestaoDeLook> sugerirLook(String id) async {
    pedidos++;
    final i = pedidos <= respostas.length ? pedidos - 1 : respostas.length - 1;
    return respostas[i]();
  }

  @override
  Future<Referencia> ligarLook(String id, String? lookId) async {
    if (falhaAoLigar != null) throw falhaAoLigar!;
    ligacoes.add(lookId);
    final atual = banco.single;
    banco[0] = Referencia(
      id: atual.id,
      imagemUrl: atual.imagemUrl,
      nota: atual.nota,
      etiquetas: atual.etiquetas,
      criadoEm: atual.criadoEm,
      look: lookId == null ? null : ReferenciaLook(id: lookId, nome: lookId == 'look-novo' ? 'Look novo' : 'Look de sexta'),
    );
    return banco[0];
  }
}

class _ColecaoServiceVazio extends ColecaoService {
  @override
  Future<List<Colecao>> listar() async => [];
}

class _LookServiceFalso extends LookServiceSemHistorico {
  final criados = <({String nome, List<String> pecaIds})>[];
  Object? falhaAoCriar;

  @override
  Future<List<Look>> listarLooks() async => [
        Look(id: 'look-1', nome: 'Look de sexta', criadoEm: DateTime(2026, 10, 20), pecas: [_calca]),
      ];

  @override
  Future<Look> criarLook({
    required String nome,
    required List<String> pecaIds,
    List<String> ocasioes = const [],
  }) async {
    if (falhaAoCriar != null) throw falhaAoCriar!;
    criados.add((nome: nome, pecaIds: pecaIds));
    return Look(id: 'look-novo', nome: nome, criadoEm: DateTime(2026, 10, 23), pecas: [_calca, _tenis]);
  }
}

Future<void> _abrirDetalhe(
  WidgetTester tester,
  _ReferenciaServiceFalso servico, {
  _LookServiceFalso? looks,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        referenciaServiceProvider.overrideWithValue(servico),
        colecaoServiceProvider.overrideWithValue(_ColecaoServiceVazio()),
        lookServiceProvider.overrideWithValue(looks ?? _LookServiceFalso()),
      ],
      child: const MaterialApp(home: ReferenciaDetalhe(id: 'a')),
    ),
  );
  await tester.pumpAndSettle();
}

/// Abre "Ligar a um look" > "Automático (IA)" e espera a sugestão chegar.
Future<void> _abrirAutomatico(WidgetTester tester) async {
  await tester.tap(find.text('Ligar a um look'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Automático (IA)'));
  await tester.pumpAndSettle();
}

void main() {
  group('escolha entre manual e automático', () {
    testWidgets('"Ligar a um look" oferece Manual e Automático (IA)', (tester) async {
      await _abrirDetalhe(tester, _ReferenciaServiceFalso());

      await tester.tap(find.text('Ligar a um look'));
      await tester.pumpAndSettle();

      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Automático (IA)'), findsOneWidget);
      expect(find.text('Adicione as etiquetas das peças da imagem primeiro'), findsNothing);
    });

    testWidgets('"Manual" abre a lista de looks de sempre', (tester) async {
      await _abrirDetalhe(tester, _ReferenciaServiceFalso());

      await tester.tap(find.text('Ligar a um look'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();

      expect(find.text('Ligar a qual look?'), findsOneWidget);
      expect(find.text('Look de sexta'), findsOneWidget);
    });

    testWidgets('sem etiquetas o automático fica desabilitado, com a dica', (tester) async {
      final servico = _ReferenciaServiceFalso(etiquetas: const []);
      await _abrirDetalhe(tester, servico);

      await tester.tap(find.text('Ligar a um look'));
      await tester.pumpAndSettle();

      expect(find.text('Adicione as etiquetas das peças da imagem primeiro'), findsOneWidget);
      final item = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Automático (IA)'));
      expect(item.enabled, isFalse);
      await tester.tap(find.text('Automático (IA)'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(SugestaoDeLookView), findsNothing);
      expect(servico.pedidos, 0);
    });

    testWidgets('"Trocar look" também oferece as duas formas', (tester) async {
      final servico = _ReferenciaServiceFalso();
      await _abrirDetalhe(tester, servico);
      await servico.ligarLook('a', 'look-1');
      await tester.pumpWidget(const SizedBox()); // recria a tela já com o look ligado
      await _abrirDetalhe(tester, servico);

      await tester.tap(find.text('Trocar look'));
      await tester.pumpAndSettle();

      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Automático (IA)'), findsOneWidget);
    });
  });

  group('espera e erros', () {
    testWidgets('mostra "Analisando…" enquanto a IA trabalha e depois o resultado', (tester) async {
      final servico = _ReferenciaServiceFalso();
      final pronto = Completer<SugestaoDeLook>();
      servico.respostas.add(() => pronto.future);
      await _abrirDetalhe(tester, servico);

      await tester.tap(find.text('Ligar a um look'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automático (IA)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Analisando a referência…'), findsOneWidget);
      expect(find.textContaining('cerca de 1 minuto'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pronto.complete(_novo());
      await tester.pumpAndSettle();
      expect(find.text('Montei um look com as suas peças'), findsOneWidget);
    });

    testWidgets('erro mostra a mensagem do servidor e "Tentar de novo" refaz a análise', (tester) async {
      final servico = _ReferenciaServiceFalso();
      servico.respostas
        ..add(() => throw _erro(422, corpo: {'detail': 'Adicione as etiquetas das peças primeiro.'}))
        ..add(_novo);
      await _abrirDetalhe(tester, servico);
      await _abrirAutomatico(tester);

      expect(find.text('Adicione as etiquetas das peças primeiro.'), findsOneWidget);
      expect(find.text('Escolher manualmente'), findsOneWidget);

      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
      expect(servico.pedidos, 2);
      expect(find.text('Montei um look com as suas peças'), findsOneWidget);
    });

    testWidgets('sem conexão avisa em português', (tester) async {
      final servico = _ReferenciaServiceFalso();
      servico.respostas.add(() => throw _erro(null, tipo: DioExceptionType.connectionError));
      await _abrirDetalhe(tester, servico);
      await _abrirAutomatico(tester);

      expect(find.textContaining('Sem conexão com o servidor'), findsOneWidget);
    });

    testWidgets('demora demais não é "sem conexão": avisa que a operação demorou', (tester) async {
      final servico = _ReferenciaServiceFalso();
      servico.respostas.add(() => throw _erro(null, tipo: DioExceptionType.connectionTimeout));
      await _abrirDetalhe(tester, servico);
      await _abrirAutomatico(tester);

      expect(find.text('A operação demorou demais. Tente novamente.'), findsOneWidget);
      expect(find.textContaining('Sem conexão'), findsNothing);
    });

    testWidgets('no erro, "Escolher manualmente" leva à lista de looks', (tester) async {
      final servico = _ReferenciaServiceFalso();
      servico.respostas.add(() => throw _erro(500));
      await _abrirDetalhe(tester, servico);
      await _abrirAutomatico(tester);
      expect(find.textContaining('Não foi possível analisar'), findsOneWidget);

      await tester.tap(find.text('Escolher manualmente'));
      await tester.pumpAndSettle();

      expect(find.byType(SugestaoDeLookView), findsNothing);
      expect(find.text('Ligar a qual look?'), findsOneWidget);
    });
  });

  group('resultado: look salvo', () {
    testWidgets('mostra o look e "Ligar a este look" liga a referência a ele', (tester) async {
      final servico = _ReferenciaServiceFalso()..respostas.add(_salvo);
      await _abrirDetalhe(tester, servico);
      await _abrirAutomatico(tester);

      expect(find.text('Encontrei um look seu parecido'), findsOneWidget);
      expect(find.text('Look de sexta'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Peças: ')), findsOneWidget);

      await tester.tap(find.text('Ligar a este look'));
      await tester.pumpAndSettle();

      expect(servico.ligacoes, ['look-1']);
      expect(find.byType(SugestaoDeLookView), findsNothing);
      expect(find.text('Look ligado'), findsOneWidget);
      expect(find.text('Referência ligada ao look.'), findsOneWidget);
    });

    testWidgets('erro ao ligar mantém a tela e avisa', (tester) async {
      final servico = _ReferenciaServiceFalso()
        ..respostas.add(_salvo)
        ..falhaAoLigar = _erro(null, tipo: DioExceptionType.connectionError);
      await _abrirDetalhe(tester, servico);
      await _abrirAutomatico(tester);

      await tester.tap(find.text('Ligar a este look'));
      await tester.pumpAndSettle();

      expect(find.byType(SugestaoDeLookView), findsOneWidget);
      expect(find.textContaining('Sem conexão com o servidor'), findsOneWidget);
    });
  });

  group('resultado: look novo', () {
    testWidgets('mostra as peças com a etiqueta que atenderam e as lacunas', (tester) async {
      final servico = _ReferenciaServiceFalso()..respostas.add(() => _novo(lacunas: ['cinto preto', 'bolsa preta']));
      await _abrirDetalhe(tester, servico);
      await _abrirAutomatico(tester);

      expect(find.text('calça jeans azul'), findsOneWidget);
      expect(find.text('Calças, jeans, azul'), findsOneWidget);
      expect(find.text('tênis branco'), findsOneWidget);
      expect(find.text('Sapatos, branco'), findsOneWidget);
      expect(find.text('Sem peça equivalente: cinto preto, bolsa preta.'), findsOneWidget);
      // Cada lacuna aparece também na lista, sem peça inventada.
      expect(find.text('Sem peça equivalente'), findsNWidgets(2));
      expect(find.text('Salvar como look e ligar'), findsOneWidget);
      expect(find.text('Ligar a este look'), findsNothing);
    });

    testWidgets('peça do tipo certo e de outra cor mostra "Cor diferente da referência"', (tester) async {
      final servico = _ReferenciaServiceFalso()
        ..respostas.add(
          () => SugestaoDeLook(
            tipo: SugestaoDeLook.tipoLookNovo,
            pecas: [_calca, _tenis],
            itens: [
              ItemDaSugestao(
                etiqueta: 'calça jeans azul',
                situacao: ItemDaSugestao.encontrada,
                peca: _calca,
              ),
              ItemDaSugestao(
                etiqueta: 'tênis preto',
                situacao: ItemDaSugestao.encontrada,
                peca: _tenis,
                corDiferente: true,
              ),
            ],
            lacunas: const [],
          ),
        );
      await _abrirDetalhe(tester, servico);
      await _abrirAutomatico(tester);

      // Só o tênis é de outra cor: a observação aparece uma vez, na linha dele.
      expect(find.text('Cor diferente da referência'), findsOneWidget);
    });

    testWidgets('etiquetas que não deu tempo de analisar aparecem à parte, sem virar lacuna', (tester) async {
      final servico = _ReferenciaServiceFalso()
        ..respostas.add(
          () => _novo(
            extras: [ItemDaSugestao(etiqueta: 'colar prata', situacao: ItemDaSugestao.naoAnalisada)],
          ),
        );
      await _abrirDetalhe(tester, servico);
      await _abrirAutomatico(tester);

      expect(find.text('Não deu tempo de analisar: colar prata.'), findsOneWidget);
      expect(find.textContaining('Sem peça equivalente:'), findsNothing);
    });

    testWidgets('"Salvar como look e ligar" cria o look com as peças e liga a referência', (tester) async {
      final servico = _ReferenciaServiceFalso(nota: 'gostei da jaqueta')..respostas.add(_novo);
      final looks = _LookServiceFalso();
      await _abrirDetalhe(tester, servico, looks: looks);
      await _abrirAutomatico(tester);

      await tester.tap(find.text('Salvar como look e ligar'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Inspirado em gostei da jaqueta'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Look inspirado');
      await tester.pump();
      await tester.tap(find.text('Salvar e ligar'));
      await tester.pumpAndSettle();

      expect(looks.criados, hasLength(1));
      expect(looks.criados.single.nome, 'Look inspirado');
      expect(looks.criados.single.pecaIds, ['calca', 'tenis']);
      expect(servico.ligacoes, ['look-novo']);
      expect(find.byType(SugestaoDeLookView), findsNothing);
      expect(find.text('Look ligado'), findsOneWidget);
      expect(find.text('Look novo'), findsOneWidget); // o nome do look ligado, como o servidor falso o devolve
    });

    testWidgets('sem nota o nome sugerido usa a data', (tester) async {
      final servico = _ReferenciaServiceFalso()..respostas.add(_novo);
      await _abrirDetalhe(tester, servico);
      await _abrirAutomatico(tester);

      await tester.tap(find.text('Salvar como look e ligar'));
      await tester.pumpAndSettle();

      final hoje = DateTime.now();
      final dd = hoje.day.toString().padLeft(2, '0');
      final mm = hoje.month.toString().padLeft(2, '0');
      expect(find.widgetWithText(TextField, 'Inspirado em uma referência – $dd/$mm'), findsOneWidget);
    });

    testWidgets('cancelar o nome não salva nem liga nada', (tester) async {
      final servico = _ReferenciaServiceFalso()..respostas.add(_novo);
      final looks = _LookServiceFalso();
      await _abrirDetalhe(tester, servico, looks: looks);
      await _abrirAutomatico(tester);

      await tester.tap(find.text('Salvar como look e ligar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(looks.criados, isEmpty);
      expect(servico.ligacoes, isEmpty);
      expect(find.byType(SugestaoDeLookView), findsOneWidget);
    });

    testWidgets('nome vazio não deixa salvar', (tester) async {
      final servico = _ReferenciaServiceFalso()..respostas.add(_novo);
      await _abrirDetalhe(tester, servico);
      await _abrirAutomatico(tester);
      await tester.tap(find.text('Salvar como look e ligar'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Salvar e ligar')).onPressed, isNull);
    });

    testWidgets('se salvar o look falha, nada é ligado e a tela fica', (tester) async {
      final servico = _ReferenciaServiceFalso()..respostas.add(_novo);
      final looks = _LookServiceFalso()
        ..falhaAoCriar = _erro(null, tipo: DioExceptionType.connectionError);
      await _abrirDetalhe(tester, servico, looks: looks);
      await _abrirAutomatico(tester);

      await tester.tap(find.text('Salvar como look e ligar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar e ligar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sem conexão com o servidor'), findsOneWidget);
      expect(servico.ligacoes, isEmpty);
      expect(find.byType(SugestaoDeLookView), findsOneWidget);
    });

    testWidgets('se o look salva mas a ligação falha, o look fica salvo e avisa', (tester) async {
      final servico = _ReferenciaServiceFalso()
        ..respostas.add(_novo)
        ..falhaAoLigar = _erro(null, tipo: DioExceptionType.connectionError);
      final looks = _LookServiceFalso();
      await _abrirDetalhe(tester, servico, looks: looks);
      await _abrirAutomatico(tester);

      await tester.tap(find.text('Salvar como look e ligar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar e ligar'));
      await tester.pumpAndSettle();

      expect(looks.criados, hasLength(1)); // salvo uma vez só
      expect(find.textContaining('O look foi salvo, mas não deu para ligá-lo'), findsOneWidget);
      expect(find.byType(SugestaoDeLookView), findsNothing);
      expect(find.text('Ligar a um look'), findsOneWidget); // a referência segue sem look
    });
  });

  group('resultado: nada encontrado e descarte', () {
    testWidgets('sem peças: explica, lista as lacunas e oferece o modo manual', (tester) async {
      final servico = _ReferenciaServiceFalso()..respostas.add(_semPecas);
      await _abrirDetalhe(tester, servico);
      await _abrirAutomatico(tester);

      expect(find.text('Não encontrei peças suas parecidas'), findsOneWidget);
      expect(find.text('Sem peça equivalente: cinto preto, coisa estranha.'), findsOneWidget);
      expect(find.text('Não entendi esta peça'), findsOneWidget);
      expect(find.text('Salvar como look e ligar'), findsNothing);
      expect(find.text('Ligar a este look'), findsNothing);

      await tester.tap(find.text('Escolher manualmente'));
      await tester.pumpAndSettle();
      expect(find.text('Ligar a qual look?'), findsOneWidget);
    });

    testWidgets('"Descartar" volta ao detalhe sem mudar nada', (tester) async {
      final servico = _ReferenciaServiceFalso()..respostas.add(_novo);
      final looks = _LookServiceFalso();
      await _abrirDetalhe(tester, servico, looks: looks);
      await _abrirAutomatico(tester);

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.byType(SugestaoDeLookView), findsNothing);
      expect(find.text('Ligar a um look'), findsOneWidget);
      expect(servico.ligacoes, isEmpty);
      expect(looks.criados, isEmpty);
    });

    testWidgets('voltar pelo sistema também não grava nada', (tester) async {
      final servico = _ReferenciaServiceFalso()..respostas.add(_salvo);
      await _abrirDetalhe(tester, servico);
      await _abrirAutomatico(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(servico.ligacoes, isEmpty);
      expect(find.text('Ligar a um look'), findsOneWidget);
    });
  });

  group('serviço', () {
    late HttpClientAdapter original;
    late _AdaptadorQueAnota adaptador;

    setUp(() {
      original = ApiClient.instance.httpClientAdapter;
      adaptador = _AdaptadorQueAnota();
      ApiClient.instance.httpClientAdapter = adaptador;
    });

    tearDown(() => ApiClient.instance.httpClientAdapter = original);

    test('a chamada de sugestão espera até 150 s; as demais seguem com o tempo padrão', () async {
      final sugestao = await ReferenciaService().sugerirLook('xyz');

      final pedido = adaptador.ultimo!;
      expect(pedido.method, 'POST');
      expect(pedido.path, '/referencias/xyz/sugestao-de-look');
      expect(pedido.receiveTimeout, const Duration(seconds: 150));
      // No navegador o "connectTimeout" vale até a resposta começar: tem de cobrir a análise.
      expect(pedido.connectTimeout, const Duration(seconds: 150));
      expect(ApiClient.instance.options.receiveTimeout, const Duration(seconds: 60));
      expect(ApiClient.instance.options.connectTimeout, const Duration(seconds: 15));

      // O JSON do backend vira o modelo, só com peças do usuário e as lacunas.
      expect(sugestao.tipo, SugestaoDeLook.tipoLookNovo);
      expect(sugestao.pecas.single.id, 'calca');
      expect(sugestao.itens.map((i) => i.situacao), [
        ItemDaSugestao.encontrada,
        ItemDaSugestao.semPecaEquivalente,
        ItemDaSugestao.naoAnalisada,
      ]);
      expect(sugestao.itens.first.peca!.categoria, 'Calças');
      expect(sugestao.itens.first.corDiferente, isTrue);
      expect(sugestao.itens[1].corDiferente, isFalse); // campo ausente = falso
      expect(sugestao.lacunas, ['cinto preto']);
      expect(sugestao.naoAnalisadas, ['colar prata']);
      expect(sugestao.look, isNull);
    });
  });
}

/// Anota a última requisição e responde com uma sugestão de exemplo.
class _AdaptadorQueAnota implements HttpClientAdapter {
  RequestOptions? ultimo;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ultimo = options;
    final peca = {
      'id': 'calca',
      'usuario_id': 'u',
      'imagem_url': '/uploads/calca.png',
      'categoria': 'Calças',
      'criado_em': '2026-10-23T10:00:00Z',
    };
    return ResponseBody.fromString(
      jsonEncode({
        'tipo': 'look_novo',
        'look': null,
        'pecas': [peca],
        'itens': [
          {'etiqueta': 'calça azul', 'peca': peca, 'situacao': 'encontrada', 'cor_diferente': true},
          {'etiqueta': 'cinto preto', 'peca': null, 'situacao': 'sem_peca_equivalente'},
          {'etiqueta': 'colar prata', 'peca': null, 'situacao': 'nao_analisada'},
        ],
        'lacunas': ['cinto preto'],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
