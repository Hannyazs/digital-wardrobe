// Pastas na aba Looks (E3.F6.2) e "Mover para pasta" (E3.F6.3). Serviços
// falsos em memória, que imitam o backend (contagem, filtro, 409, exclusão).
// Ver docs/PBIs/E3-criacao-manual-de-looks/E3-F6-pastas-de-looks/.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/pasta_look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/services/pasta_service.dart';
import 'package:guarda_roupa_app/views/looks/looks_controller.dart';
import 'package:guarda_roupa_app/views/looks/looks_view.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/looks/pastas_controller.dart';

import 'support/look_service_sem_historico.dart';

DioException _erro(int? status) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: status == null ? null : Response(requestOptions: RequestOptions(path: '/x'), statusCode: status),
      type: status == null ? DioExceptionType.connectionError : DioExceptionType.badResponse,
    );

Look _look(String id, String nome, {String? pastaId, bool favorito = false}) => Look(
      id: id,
      nome: nome,
      criadoEm: DateTime(2026, 1, 1),
      favorito: favorito,
      pastaId: pastaId,
      pecas: [Peca(id: 'p$id', imagemUrl: '/uploads/$id.png', categoria: 'Camisetas')],
    );

Look _comPasta(Look l, String? pastaId) =>
    Look(id: l.id, nome: l.nome, criadoEm: l.criadoEm, pecas: l.pecas, favorito: l.favorito, pastaId: pastaId);

/// O "servidor": os looks e as pastas, em memória.
class _Servidor {
  _Servidor(this.looks, Map<String, String> pastas) : pastas = {...pastas};

  List<Look> looks;
  final Map<String, String> pastas; // id → nome
  var _proximoId = 0;

  int quantidade(String pastaId) => looks.where((l) => l.pastaId == pastaId).length;
}

class _LookService extends LookServiceSemHistorico {
  _LookService(this.servidor, {this.erroAoMover});

  final _Servidor servidor;
  final DioException? erroAoMover;
  final patches = <Map<String, dynamic>>[];

  @override
  Future<List<Look>> listarLooks() async => servidor.looks;

  @override
  Future<List<Look>> listarLooksDaPasta({String? pastaId, bool semPasta = false}) async =>
      servidor.looks.where((l) => semPasta ? l.pastaId == null : l.pastaId == pastaId).toList();

  @override
  Future<Look> atualizarLook(String id, Map<String, dynamic> campos) async {
    patches.add(campos);
    if (erroAoMover != null && campos.containsKey('pasta_id')) throw erroAoMover!;
    servidor.looks = [
      for (final l in servidor.looks) l.id == id && campos.containsKey('pasta_id') ? _comPasta(l, campos['pasta_id'] as String?) : l,
    ];
    return servidor.looks.firstWhere((l) => l.id == id);
  }
}

class _PastaService extends PastaService {
  _PastaService(this.servidor);

  final _Servidor servidor;

  PastaLook _pasta(String id) =>
      PastaLook(id: id, nome: servidor.pastas[id]!, criadoEm: DateTime(2026), quantidade: servidor.quantidade(id));

  void _semRepetir(String nome, {String? ignorar}) {
    final repetido = servidor.pastas.entries.any((e) => e.key != ignorar && e.value.toLowerCase() == nome.toLowerCase());
    if (repetido) throw _erro(409);
  }

  @override
  Future<List<PastaLook>> listar() async => [for (final id in servidor.pastas.keys) _pasta(id)]
    ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

  @override
  Future<PastaLook> criar(String nome) async {
    _semRepetir(nome);
    final id = 'nova-${servidor._proximoId++}';
    servidor.pastas[id] = nome;
    return _pasta(id);
  }

  @override
  Future<PastaLook> renomear(String id, String nome) async {
    _semRepetir(nome, ignorar: id);
    servidor.pastas[id] = nome;
    return _pasta(id);
  }

  @override
  Future<void> excluir(String id) async {
    servidor.pastas.remove(id);
    servidor.looks = [for (final l in servidor.looks) l.pastaId == id ? _comPasta(l, null) : l];
  }
}

/// Dois looks em "Trabalho" (um favorito), um sem pasta; "Viagem" vazia.
_Servidor _servidorPadrao() => _Servidor(
      [
        _look('1', 'Reunião', pastaId: 'trabalho', favorito: true),
        _look('2', 'Escritório casual', pastaId: 'trabalho'),
        _look('3', 'Domingo'),
      ],
      {'trabalho': 'Trabalho', 'viagem': 'Viagem'},
    );

Future<ProviderContainer> _abrir(WidgetTester tester, _Servidor servidor, {_LookService? looks}) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    lookServiceProvider.overrideWithValue(looks ?? _LookService(servidor)),
    pastaServiceProvider.overrideWithValue(_PastaService(servidor)),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MaterialApp(home: LooksView())),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tocarNoChip(WidgetTester tester, String rotulo) async {
  await tester.tap(find.widgetWithText(ChoiceChip, rotulo));
  await tester.pumpAndSettle();
}

/// Abre o menu "⋮" do card do look [nome] e escolhe [opcao].
Future<void> _menuDoLook(WidgetTester tester, String nome, String opcao) async {
  final card = find.ancestor(of: find.text(nome), matching: find.byType(Card));
  await tester.tap(find.descendant(of: card, matching: find.byTooltip('Mais opções')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(opcao).last);
  await tester.pumpAndSettle();
}

Finder _naFolha(String texto) => find.descendant(of: find.byType(BottomSheet), matching: find.text(texto));

/// Fecha o app e deixa o Riverpod descartar os providers `autoDispose`.
Future<void> _fechar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

void main() {
  group('Chips de pastas (E3.F6.2)', () {
    testWidgets('Mostra Todos, cada pasta com a quantidade, Sem pasta e Nova pasta', (tester) async {
      await _abrir(tester, _servidorPadrao());

      for (final rotulo in ['Todos', 'Trabalho (2)', 'Viagem (0)', 'Sem pasta']) {
        expect(find.widgetWithText(ChoiceChip, rotulo), findsOneWidget);
      }
      expect(find.widgetWithText(ActionChip, 'Nova pasta'), findsOneWidget);
      expect(find.text('3 looks'), findsOneWidget);
      await _fechar(tester);
    });

    testWidgets('Tocar numa pasta mostra só os looks dela; Sem pasta mostra os de fora', (tester) async {
      await _abrir(tester, _servidorPadrao());

      await _tocarNoChip(tester, 'Trabalho (2)');
      expect(find.text('Reunião'), findsOneWidget);
      expect(find.text('Escritório casual'), findsOneWidget);
      expect(find.text('Domingo'), findsNothing);

      await _tocarNoChip(tester, 'Sem pasta');
      expect(find.text('Domingo'), findsOneWidget);
      expect(find.text('Reunião'), findsNothing);
      await _fechar(tester);
    });

    testWidgets('Pasta escolhida + Favoritos: só os favoritos daquela pasta', (tester) async {
      final container = await _abrir(tester, _servidorPadrao());

      await _tocarNoChip(tester, 'Trabalho (2)');
      container.read(filtroLooksProvider.notifier).state = const FiltroLooks(somenteFavoritos: true);
      await tester.pumpAndSettle();

      expect(find.text('Reunião'), findsOneWidget);
      expect(find.text('Escritório casual'), findsNothing);
      expect(find.text('Domingo'), findsNothing);
      expect(find.text('1 de 2 looks'), findsOneWidget);
      await _fechar(tester);
    });

    testWidgets('Pasta sem looks mostra a orientação de vazio, não um erro', (tester) async {
      await _abrir(tester, _servidorPadrao());

      await _tocarNoChip(tester, 'Viagem (0)');

      expect(find.text('Esta pasta ainda não tem looks'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
      await _fechar(tester);
    });

    testWidgets('Criar pasta: aparece nos chips; nome repetido mostra a mensagem', (tester) async {
      await _abrir(tester, _servidorPadrao());

      await tester.ensureVisible(find.widgetWithText(ActionChip, 'Nova pasta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Nova pasta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Praia  ');
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Praia (0)'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(ActionChip, 'Nova pasta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Nova pasta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'TRABALHO');
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Já existe uma pasta com esse nome.'), findsOneWidget);
      await _fechar(tester);
    });

    testWidgets('Renomear pela opção da pasta escolhida', (tester) async {
      await _abrir(tester, _servidorPadrao());

      await _tocarNoChip(tester, 'Trabalho (2)');
      await tester.tap(find.byTooltip('Opções da pasta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renomear pasta'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Trabalho');
      await tester.enterText(find.byType(TextField), 'Escritório');
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Escritório (2)'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Trabalho (2)'), findsNothing);
      await _fechar(tester);
    });

    testWidgets('Excluir a pasta escolhida: volta para Todos e os looks continuam, sem pasta', (tester) async {
      final container = await _abrir(tester, _servidorPadrao());

      await _tocarNoChip(tester, 'Trabalho (2)');
      await tester.tap(find.byTooltip('Opções da pasta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir pasta'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir a pasta "Trabalho"?'), findsOneWidget);
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Trabalho (2)'), findsNothing);
      expect(container.read(pastaSelecionadaProvider), SelecaoPasta.todos);
      expect(find.text('3 looks'), findsOneWidget);

      await _tocarNoChip(tester, 'Sem pasta');
      for (final nome in ['Reunião', 'Escritório casual', 'Domingo']) {
        expect(find.text(nome), findsOneWidget);
      }
      await _fechar(tester);
    });

    testWidgets('Cancelar a exclusão não apaga a pasta', (tester) async {
      await _abrir(tester, _servidorPadrao());

      await _tocarNoChip(tester, 'Trabalho (2)');
      await tester.tap(find.byTooltip('Opções da pasta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir pasta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Trabalho (2)'), findsOneWidget);
      await _fechar(tester);
    });
  });

  group('Mover para pasta (E3.F6.3)', () {
    testWidgets('Look sem pasta → uma pasta: aparece nela e a contagem sobe', (tester) async {
      final servidor = _servidorPadrao();
      final looks = _LookService(servidor);
      await _abrir(tester, servidor, looks: looks);

      await _menuDoLook(tester, 'Domingo', 'Mover para pasta');
      expect(_naFolha('Sem pasta'), findsOneWidget);
      await tester.tap(_naFolha('Viagem'));
      await tester.pumpAndSettle();

      expect(looks.patches, [
        {'pasta_id': 'viagem'},
      ]);
      expect(find.widgetWithText(ChoiceChip, 'Viagem (1)'), findsOneWidget);
      expect(find.text('Look "Domingo" movido para "Viagem".'), findsOneWidget);

      await _tocarNoChip(tester, 'Viagem (1)');
      expect(find.text('Domingo'), findsOneWidget);
      await _fechar(tester);
    });

    testWidgets('Look numa pasta → Sem pasta: sai dela (pasta_id null)', (tester) async {
      final servidor = _servidorPadrao();
      final looks = _LookService(servidor);
      await _abrir(tester, servidor, looks: looks);

      await _menuDoLook(tester, 'Reunião', 'Mover para pasta');
      await tester.tap(_naFolha('Sem pasta'));
      await tester.pumpAndSettle();

      expect(looks.patches, [
        {'pasta_id': null},
      ]);
      expect(find.widgetWithText(ChoiceChip, 'Trabalho (1)'), findsOneWidget);
      await _fechar(tester);
    });

    testWidgets('"Nova pasta…" cria a pasta e o look já fica nela', (tester) async {
      final servidor = _servidorPadrao();
      final looks = _LookService(servidor);
      await _abrir(tester, servidor, looks: looks);

      await _menuDoLook(tester, 'Domingo', 'Mover para pasta');
      await tester.tap(_naFolha('Nova pasta…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Fim de semana');
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(looks.patches.single['pasta_id'], startsWith('nova-'));
      expect(find.widgetWithText(ChoiceChip, 'Fim de semana (1)'), findsOneWidget);
      await _fechar(tester);
    });

    testWidgets('Falha de rede: aparece a mensagem e o look continua onde estava', (tester) async {
      final servidor = _servidorPadrao();
      await _abrir(tester, servidor, looks: _LookService(servidor, erroAoMover: _erro(null)));

      await _menuDoLook(tester, 'Domingo', 'Mover para pasta');
      await tester.tap(_naFolha('Viagem'));
      await tester.pumpAndSettle();

      expect(find.text('Sem conexão com o servidor. Não foi possível mover o look.'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Viagem (0)'), findsOneWidget);
      expect(servidor.looks.firstWhere((l) => l.id == '3').pastaId, isNull);
      await _fechar(tester);
    });

    testWidgets('O card mostra a pasta em Todos, mas não dentro da própria pasta', (tester) async {
      final semantica = tester.ensureSemantics();
      await _abrir(tester, _servidorPadrao());

      expect(find.bySemanticsLabel(RegExp('Pasta: Trabalho')), findsNWidgets(2));

      await _tocarNoChip(tester, 'Trabalho (2)');
      expect(find.bySemanticsLabel(RegExp('Pasta: Trabalho')), findsNothing);
      semantica.dispose();
      await _fechar(tester);
    });

    testWidgets('O seletor marca a pasta atual', (tester) async {
      await _abrir(tester, _servidorPadrao());

      await _menuDoLook(tester, 'Reunião', 'Mover para pasta');

      final atual = tester.widget<ListTile>(find.ancestor(of: _naFolha('Trabalho'), matching: find.byType(ListTile)));
      final outra = tester.widget<ListTile>(find.ancestor(of: _naFolha('Viagem'), matching: find.byType(ListTile)));
      expect(atual.selected, isTrue);
      expect(outra.selected, isFalse);
      await _fechar(tester);
    });
  });
}
