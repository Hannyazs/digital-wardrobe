// Aviso de peça parada ao abrir o app (E13.F1.2) e as ações dele: doar e
// sugerir look (E13.F1.3). Serviços falsos, nunca bate numa API real.
// Ver docs/PBIs/E13-pecas-paradas/E13-F1-pecas-paradas/.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/models/peca_parada.dart';
import 'package:guarda_roupa_app/models/sugestao.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/services/sugestao_service.dart' show FiltroSugestoes;
import 'package:guarda_roupa_app/views/home/home_shell.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/preferences/preferences_controller.dart'
    show preferenciaServiceProvider;
import 'package:guarda_roupa_app/views/suggestions/suggestions_controller.dart' show sugestaoServiceProvider;
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;

import 'support/look_service_sem_historico.dart';
import 'support/pagina_da_lista.dart';
import 'support/preferencia_service_sem_evitadas.dart';
import 'support/sugestao_service_sem_look_do_dia.dart';

final _vestido = Peca(
  id: 'peca-1',
  imagemUrl: '/uploads/peca-1.png',
  categoria: 'Vestidos',
  subcategoria: 'Longo',
  corPrincipal: 'Azul',
  estilos: ['Elegante'],
  ocasioes: ['Festa'],
);

final _colar = Peca(id: 'peca-2', imagemUrl: '/uploads/peca-2.png', categoria: 'Acessórios');

PecaParada _parada(Peca peca, {DateTime? ultimoUso, int dias = 120}) =>
    PecaParada(peca: peca, ultimoUso: ultimoUso, diasParada: dias);

DioException _erro(int? status, {Object? dados}) => DioException(
      requestOptions: RequestOptions(path: '/pecas'),
      response: status == null
          ? null
          : Response(requestOptions: RequestOptions(path: '/pecas'), statusCode: status, data: dados),
      type: status == null ? DioExceptionType.connectionError : DioExceptionType.badResponse,
    );

/// O "servidor" das peças paradas: devolve [paradas] até a peça ser adiada ou
/// excluída, e registra cada chamada.
class _PecaServiceParadas extends PecaService with PaginaDaLista {
  _PecaServiceParadas(this.paradas, {this.erroAoListar, this.erroAoAdiar, this.emLooks = 0});

  List<PecaParada> paradas;
  final DioException? erroAoListar;
  final DioException? erroAoAdiar;
  final int emLooks;

  int buscas = 0;
  final adiadas = <String>[];
  final exclusoes = <({String id, bool removerDosLooks})>[];
  DateTime? hojeDaBusca;

  @override
  Future<List<Peca>> listarPecas() async => paradas.map((p) => p.peca).toList();

  @override
  Future<List<PecaParada>> listarParadas({required DateTime hoje, int limite = 1}) async {
    buscas++;
    hojeDaBusca = hoje;
    if (erroAoListar != null) throw erroAoListar!;
    return paradas.take(limite).toList();
  }

  @override
  Future<void> adiarLembrete(String id, {required DateTime hoje}) async {
    if (erroAoAdiar != null) throw erroAoAdiar!;
    adiadas.add(id);
    paradas = paradas.where((p) => p.peca.id != id).toList();
  }

  @override
  Future<void> excluirPeca(String id, {bool removerDosLooks = false}) async {
    exclusoes.add((id: id, removerDosLooks: removerDosLooks));
    if (emLooks > 0 && !removerDosLooks) {
      throw _erro(409, dados: {
        'detail': {'codigo': 'peca_em_looks', 'looks': emLooks, 'mensagem': 'Em looks.'},
      });
    }
    paradas = paradas.where((p) => p.peca.id != id).toList();
  }
}

/// Responde a busca só quando o teste completar [resposta].
class _PecaServiceLento extends _PecaServiceParadas {
  _PecaServiceLento(super.paradas, this.resposta);

  final Completer<List<PecaParada>> resposta;

  @override
  Future<List<PecaParada>> listarParadas({required DateTime hoje, int limite = 1}) => resposta.future;
}

class _LookServiceVazio extends LookServiceSemHistorico {
  @override
  Future<List<Look>> listarLooks() async => [];
}

class _SugestaoServiceRegistra extends SugestaoServiceSemLookDoDia {
  final pecasBase = <String?>[];

  @override
  Future<PaginaSugestoes> sugerir({
    FiltroSugestoes filtros = const FiltroSugestoes(),
    String? pecaBaseId,
    int pagina = 1,
    List<List<String>> descartados = const [],
  }) async {
    pecasBase.add(pecaBaseId);
    return const PaginaSugestoes(motivo: 'Nenhum look encontrado.');
  }
}

/// Monta o app (a `HomeShell`) num [container] já pronto, para os testes que
/// "reabrem" o app na mesma sessão.
Future<void> _abrirApp(WidgetTester tester, ProviderContainer container) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MaterialApp(home: HomeShell())),
  );
  await tester.pumpAndSettle();
}

/// Fecha o app e deixa o Riverpod descartar os providers `autoDispose` (ele
/// agenda isso em timers de duração zero, um por nível de dependência, que o
/// teste precisa deixar rodar).
Future<void> _fecharApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

ProviderContainer _container(_PecaServiceParadas pecas, {_SugestaoServiceRegistra? sugestoes}) {
  final container = ProviderContainer(overrides: [
    pecaServiceProvider.overrideWithValue(pecas),
    lookServiceProvider.overrideWithValue(_LookServiceVazio()),
    sugestaoServiceProvider.overrideWithValue(sugestoes ?? _SugestaoServiceRegistra()),
    preferenciaServiceProvider.overrideWithValue(PreferenciaServiceSemEvitadas()),
  ]);
  addTearDown(container.dispose);
  return container;
}

Future<void> _abrir(WidgetTester tester, _PecaServiceParadas pecas, {_SugestaoServiceRegistra? sugestoes}) =>
    _abrirApp(tester, _container(pecas, sugestoes: sugestoes));

final _aviso = find.text('Peça parada');

void main() {
  group('Aviso (E13.F1.2)', () {
    testWidgets('Peça parada: o aviso abre com a foto, a descrição e os três botões', (tester) async {
      final semantica = tester.ensureSemantics();
      final pecas = _PecaServiceParadas([_parada(_vestido, ultimoUso: DateTime(2026, 6, 1), dias: 158)]);
      await _abrir(tester, pecas);

      expect(_aviso, findsOneWidget);
      expect(find.text('Vestidos, Longo, azul'), findsOneWidget);
      expect(find.text('Você não usa esta peça há 158 dias.'), findsOneWidget);
      expect(find.bySemanticsLabel('Foto da peça: Vestidos, Longo, azul'), findsOneWidget);
      for (final botao in ['Doar a peça', 'Sugerir look com ela', 'Lembrar depois']) {
        expect(find.text(botao), findsOneWidget);
        expect(tester.getSize(find.ancestor(of: find.text(botao), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)).first).height,
            greaterThanOrEqualTo(48));
      }
      expect(pecas.buscas, 1);
      final hoje = DateTime.now();
      expect(pecas.hojeDaBusca?.day, hoje.day);
      semantica.dispose();
    });

    testWidgets('Peça nunca usada: "Você ainda não usou esta peça"', (tester) async {
      await _abrir(tester, _PecaServiceParadas([_parada(_vestido, dias: 95)]));

      expect(find.text('Você ainda não usou esta peça.'), findsOneWidget);
    });

    testWidgets('"Lembrar depois" fecha, adia na API e a peça não volta na próxima abertura', (tester) async {
      final pecas = _PecaServiceParadas([_parada(_vestido)]);
      await _abrir(tester, pecas);

      await tester.tap(find.text('Lembrar depois'));
      await tester.pumpAndSettle();

      expect(_aviso, findsNothing);
      expect(pecas.adiadas, ['peca-1']);

      // Próxima abertura do app = nova sessão (novo container).
      await _abrir(tester, pecas);
      expect(_aviso, findsNothing);
      await _fecharApp(tester);
    });

    testWidgets('Fechar sem escolher não adia, não reabre na sessão e volta na próxima abertura', (tester) async {
      final pecas = _PecaServiceParadas([_parada(_vestido)]);
      final sessao = _container(pecas);
      await _abrirApp(tester, sessao);

      await tester.tapAt(const Offset(5, 5)); // fora do diálogo
      await tester.pumpAndSettle();
      expect(_aviso, findsNothing);
      expect(pecas.adiadas, isEmpty);

      // A casca é recriada na mesma sessão (ex.: depois de cadastrar uma peça).
      await _fecharApp(tester);
      await _abrirApp(tester, sessao);
      expect(_aviso, findsNothing);

      // Nova sessão: o aviso volta.
      await _abrir(tester, pecas);
      expect(_aviso, findsOneWidget);
      await _fecharApp(tester);
    });

    testWidgets('Nenhuma peça parada: nada aparece', (tester) async {
      await _abrir(tester, _PecaServiceParadas([]));

      expect(_aviso, findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });

    for (final (nome, erro) in [('sem rede', _erro(null)), ('401', _erro(401))]) {
      testWidgets('Falha na busca ($nome): o app abre normalmente, sem mensagem', (tester) async {
        await _abrir(tester, _PecaServiceParadas([_parada(_vestido)], erroAoListar: erro));

        expect(_aviso, findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.text('Casa'), findsOneWidget);
      });
    }

    testWidgets('Falha ao adiar: fecha o aviso e avisa que a peça pode voltar', (tester) async {
      await _abrir(tester, _PecaServiceParadas([_parada(_vestido)], erroAoAdiar: _erro(null)));

      await tester.tap(find.text('Lembrar depois'));
      await tester.pumpAndSettle();

      expect(_aviso, findsNothing);
      expect(find.text('Não foi possível adiar o lembrete. A peça pode aparecer de novo.'), findsOneWidget);
    });

    testWidgets('Não abre por cima de uma tela empilhada', (tester) async {
      final resposta = Completer<List<PecaParada>>();
      final pecas = _PecaServiceLento([_parada(_vestido)], resposta);
      await _abrir(tester, pecas);

      // A busca termina só depois de outra tela ser empilhada sobre a casca.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Tela empilhada')))));
      await tester.pumpAndSettle();
      resposta.complete(pecas.paradas);
      await tester.pumpAndSettle();

      expect(find.text('Tela empilhada'), findsOneWidget);
      expect(_aviso, findsNothing);
    });
  });

  group('Doar e sugerir (E13.F1.3)', () {
    testWidgets('Doar e confirmar exclui a peça, fecha o aviso e ela some do armário', (tester) async {
      final semantica = tester.ensureSemantics();
      final camiseta = Peca(id: 'peca-3', imagemUrl: '/uploads/peca-3.png', categoria: 'Camisetas', corPrincipal: 'Branco');
      final pecas = _PecaServiceParadas([_parada(_vestido), _parada(camiseta, dias: 91)]);
      await _abrir(tester, pecas);

      await tester.tap(find.text('Doar a peça'));
      await tester.pumpAndSettle();
      expect(find.text('Doar e remover do app?'), findsOneWidget);
      await tester.tap(find.text('Remover do app'));
      await tester.pumpAndSettle();

      expect(pecas.exclusoes, [(id: 'peca-1', removerDosLooks: false)]);
      expect(_aviso, findsNothing);

      await tester.tap(find.text('Armário'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Camisetas, branco'), findsOneWidget);
      expect(find.bySemanticsLabel('Vestidos, Longo, azul'), findsNothing);
      semantica.dispose();
    });

    testWidgets('Doar e cancelar a confirmação não exclui e o aviso continua', (tester) async {
      final pecas = _PecaServiceParadas([_parada(_vestido)]);
      await _abrir(tester, pecas);

      await tester.tap(find.text('Doar a peça'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(pecas.exclusoes, isEmpty);
      expect(_aviso, findsOneWidget);
    });

    testWidgets('Peça em looks: o aviso de looks aparece antes de excluir', (tester) async {
      final pecas = _PecaServiceParadas([_parada(_vestido)], emLooks: 2);
      await _abrir(tester, pecas);

      await tester.tap(find.text('Doar a peça'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover do app'));
      await tester.pumpAndSettle();

      expect(find.text('Peça usada em looks'), findsOneWidget);
      expect(find.textContaining('está em 2 looks'), findsOneWidget);
      expect(pecas.exclusoes, [(id: 'peca-1', removerDosLooks: false)]);

      await tester.tap(find.text('Excluir mesmo assim'));
      await tester.pumpAndSettle();

      expect(pecas.exclusoes.last, (id: 'peca-1', removerDosLooks: true));
      expect(_aviso, findsNothing);
    });

    testWidgets('"Sugerir look com ela" abre as sugestões com a peça fixa, sem adiar', (tester) async {
      final pecas = _PecaServiceParadas([_parada(_vestido)]);
      final sugestoes = _SugestaoServiceRegistra();
      await _abrir(tester, pecas, sugestoes: sugestoes);

      await tester.tap(find.text('Sugerir look com ela'));
      await tester.pumpAndSettle();

      expect(_aviso, findsNothing);
      expect(find.text('Looks com esta peça'), findsOneWidget);
      expect(sugestoes.pecasBase, contains('peca-1'));
      expect(pecas.adiadas, isEmpty);
    });

    testWidgets('Acessório não tem o botão "Sugerir look com ela"', (tester) async {
      await _abrir(tester, _PecaServiceParadas([_parada(_colar)]));

      expect(_aviso, findsOneWidget);
      expect(find.text('Sugerir look com ela'), findsNothing);
      expect(find.text('Doar a peça'), findsOneWidget);
      expect(find.text('Lembrar depois'), findsOneWidget);
    });
  });
}
