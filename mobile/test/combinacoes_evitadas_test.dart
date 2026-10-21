// Testes das combinações de peças evitadas (E4.F4.3): seção na tela de
// preferências e escolha do par (`EscolherParView`). Serviços falsos.
// Ver docs/PBIs/E4-F4-pecas-e-combinacoes-evitadas/E4.F4.3-combinacoes-evitadas-no-app.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/core/widgets/clothing_card.dart';
import 'package:guarda_roupa_app/models/evitadas.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/preferences/escolher_par_view.dart';
import 'package:guarda_roupa_app/views/preferences/preferences_controller.dart';
import 'package:guarda_roupa_app/views/preferences/preferences_view.dart';
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;

import 'support/preferencia_service_sem_evitadas.dart';

// Na grade, as categorias seguem `categoriasFixas`: Camisetas, ..., Calças, ..., Sapatos.
final _camiseta = Peca(id: 'p1', imagemUrl: '/uploads/p1.png', categoria: 'Camisetas');
final _calca = Peca(id: 'p2', imagemUrl: '/uploads/p2.png', categoria: 'Calças');
final _sapato = Peca(id: 'p3', imagemUrl: '/uploads/p3.png', categoria: 'Sapatos');

DioException _erro(String caminho, {int? status}) {
  final opts = RequestOptions(path: caminho);
  return status == null
      ? DioException(requestOptions: opts, type: DioExceptionType.connectionError)
      : DioException(
          requestOptions: opts,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: opts, statusCode: status),
        );
}

/// Fake com estado: o mesmo par em qualquer ordem não duplica (como o backend).
class _PreferenciaServicePares extends PreferenciaServiceSemEvitadas {
  _PreferenciaServicePares([List<CombinacaoEvitada>? combinacoes])
      : combinacoes = combinacoes ?? [];

  List<CombinacaoEvitada> combinacoes;
  DioException? erroAoAdicionar;
  DioException? erroAoRemover;
  final pedidos = <(String, String)>[];
  int _proximoId = 1;

  @override
  Future<Evitadas> listarEvitadas() async => Evitadas(combinacoes: List.of(combinacoes));

  @override
  Future<({CombinacaoEvitada par, bool jaExistia})> evitarCombinacao(
    String pecaAId,
    String pecaBId,
  ) async {
    pedidos.add((pecaAId, pecaBId));
    if (erroAoAdicionar != null) throw erroAoAdicionar!;
    for (final par in combinacoes) {
      final ids = par.pecas.map((p) => p.id).toSet();
      if (ids.containsAll([pecaAId, pecaBId])) return (par: par, jaExistia: true);
    }
    final todas = [_camiseta, _calca, _sapato];
    final novo = CombinacaoEvitada(
      id: 'c${_proximoId++}',
      pecas: [todas.firstWhere((p) => p.id == pecaAId), todas.firstWhere((p) => p.id == pecaBId)],
    );
    combinacoes = [...combinacoes, novo];
    return (par: novo, jaExistia: false);
  }

  @override
  Future<void> pararDeEvitarCombinacao(String combinacaoId) async {
    if (erroAoRemover != null) {
      // Um 404 simula o par que já sumiu em cascata no backend.
      if (erroAoRemover!.response?.statusCode == 404) {
        combinacoes = combinacoes.where((c) => c.id != combinacaoId).toList();
      }
      throw erroAoRemover!;
    }
    combinacoes = combinacoes.where((c) => c.id != combinacaoId).toList();
  }
}

class _PecaServiceArmario extends PecaService {
  _PecaServiceArmario(this.pecas);

  final List<Peca> pecas;

  @override
  Future<List<Peca>> listarPecas() async => pecas;
}

Future<void> _abrir(
  WidgetTester tester,
  _PreferenciaServicePares preferencias, {
  List<Peca>? armario,
}) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferenciaServiceProvider.overrideWithValue(preferencias),
        pecaServiceProvider.overrideWithValue(
          _PecaServiceArmario(armario ?? [_camiseta, _calca, _sapato]),
        ),
      ],
      child: const MaterialApp(home: PreferencesView()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _abrirEscolha(WidgetTester tester) async {
  await tester.tap(find.text('Adicionar par de peças'));
  await tester.pumpAndSettle();
}

ElevatedButton _botaoEvitar(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Evitar essa combinação'));

/// Ordem da grade: 0 = Camisetas, 1 = Calças, 2 = Sapatos.
Future<void> _tocarPeca(WidgetTester tester, int indice) async {
  await tester.tap(find.byType(ClothingCard).at(indice));
  await tester.pump();
}

void main() {
  testWidgets('Seção vazia explica o que é uma combinação evitada', (tester) async {
    await _abrir(tester, _PreferenciaServicePares());

    expect(find.text('Combinações que evito'), findsOneWidget);
    expect(find.textContaining('Nenhuma combinação evitada.'), findsOneWidget);
  });

  testWidgets('"Adicionar par de peças" abre a grade do armário com o botão desabilitado', (
    tester,
  ) async {
    await _abrir(tester, _PreferenciaServicePares());
    await _abrirEscolha(tester);

    expect(find.byType(EscolherParView), findsOneWidget);
    expect(find.byType(ClothingCard), findsNWidgets(3));
    expect(_botaoEvitar(tester).onPressed, isNull);
  });

  testWidgets('O botão só habilita com exatamente duas peças', (tester) async {
    await _abrir(tester, _PreferenciaServicePares());
    await _abrirEscolha(tester);

    await _tocarPeca(tester, 0);
    expect(_botaoEvitar(tester).onPressed, isNull);
    await _tocarPeca(tester, 1);
    expect(_botaoEvitar(tester).onPressed, isNotNull);
    expect(find.textContaining('(2 de 2)'), findsOneWidget);

    // Desmarcar uma volta a desabilitar.
    await _tocarPeca(tester, 0);
    expect(_botaoEvitar(tester).onPressed, isNull);
  });

  testWidgets('Uma terceira peça é bloqueada com aviso', (tester) async {
    await _abrir(tester, _PreferenciaServicePares());
    await _abrirEscolha(tester);

    await _tocarPeca(tester, 0);
    await _tocarPeca(tester, 1);
    await _tocarPeca(tester, 2);
    await tester.pump();

    expect(find.text('Escolha só duas peças. Desmarque uma para trocar.'), findsOneWidget);
    expect(find.textContaining('(2 de 2)'), findsOneWidget);
    final cards = tester.widgetList<ClothingCard>(find.byType(ClothingCard)).toList();
    expect(cards.map((c) => c.selecionada), [true, true, false]);
  });

  testWidgets('Confirmar salva o par, volta e ele aparece na seção com as duas miniaturas', (
    tester,
  ) async {
    final service = _PreferenciaServicePares();
    await _abrir(tester, service);
    await _abrirEscolha(tester);

    await _tocarPeca(tester, 0);
    await _tocarPeca(tester, 1);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Evitar essa combinação'));
    await tester.pumpAndSettle();

    expect(service.pedidos, [('p1', 'p2')]);
    expect(find.byType(EscolherParView), findsNothing);
    expect(find.text('Camisetas + Calças'), findsOneWidget);
    expect(
      find.text('Combinação adicionada: essas peças não serão sugeridas juntas.'),
      findsOneWidget,
    );
  });

  testWidgets('O mesmo par em ordem inversa não duplica e avisa', (tester) async {
    final service = _PreferenciaServicePares([
      CombinacaoEvitada(id: 'c0', pecas: [_camiseta, _calca]),
    ]);
    await _abrir(tester, service);
    await _abrirEscolha(tester);

    // Calça antes da camiseta.
    await _tocarPeca(tester, 1);
    await _tocarPeca(tester, 0);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Evitar essa combinação'));
    await tester.pumpAndSettle();

    expect(find.text('Essa combinação já estava na lista.'), findsOneWidget);
    expect(service.combinacoes, hasLength(1));
    expect(find.text('Camisetas + Calças'), findsOneWidget);
  });

  testWidgets('Falha ao salvar mostra mensagem e mantém a escolha na tela', (tester) async {
    final service = _PreferenciaServicePares()
      ..erroAoAdicionar = _erro('/preferencias/combinacoes-evitadas');
    await _abrir(tester, service);
    await _abrirEscolha(tester);

    await _tocarPeca(tester, 0);
    await _tocarPeca(tester, 2);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Evitar essa combinação'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Não foi possível salvar a combinação.'),
      findsOneWidget,
    );
    expect(find.byType(EscolherParView), findsOneWidget);
    expect(_botaoEvitar(tester).onPressed, isNotNull);
  });

  testWidgets('Remover pede confirmação: cancelar mantém, confirmar tira da lista', (tester) async {
    final service = _PreferenciaServicePares([
      CombinacaoEvitada(id: 'c0', pecas: [_camiseta, _calca]),
      CombinacaoEvitada(id: 'c1', pecas: [_calca, _sapato]),
    ]);
    await _abrir(tester, service);

    await tester.tap(find.byTooltip('Remover Camisetas + Calças'));
    await tester.pumpAndSettle();
    expect(find.text('Remover esta combinação?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(service.combinacoes, hasLength(2));

    await tester.tap(find.byTooltip('Remover Camisetas + Calças'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remover'));
    await tester.pumpAndSettle();
    expect(service.combinacoes.map((c) => c.id), ['c1']);
    expect(find.text('Camisetas + Calças'), findsNothing);
    expect(find.text('Calças + Sapatos'), findsOneWidget);
  });

  testWidgets('Remover um par que já não existe (404) só atualiza a lista, sem erro', (
    tester,
  ) async {
    final service = _PreferenciaServicePares([
      CombinacaoEvitada(id: 'c0', pecas: [_camiseta, _calca]),
    ])..erroAoRemover = _erro('/preferencias/combinacoes-evitadas/c0', status: 404);
    await _abrir(tester, service);

    await tester.tap(find.byTooltip('Remover Camisetas + Calças'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remover'));
    await tester.pumpAndSettle();

    expect(find.text('Camisetas + Calças'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Falha de rede ao remover mostra mensagem e mantém o par', (tester) async {
    final service = _PreferenciaServicePares([
      CombinacaoEvitada(id: 'c0', pecas: [_camiseta, _calca]),
    ])..erroAoRemover = _erro('/preferencias/combinacoes-evitadas/c0');
    await _abrir(tester, service);

    await tester.tap(find.byTooltip('Remover Camisetas + Calças'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remover'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Não foi possível remover a combinação.'),
      findsOneWidget,
    );
    expect(find.text('Camisetas + Calças'), findsOneWidget);
  });

  testWidgets('Armário com menos de duas peças mostra orientação em vez da grade', (tester) async {
    await _abrir(tester, _PreferenciaServicePares(), armario: [_camiseta]);
    await _abrirEscolha(tester);

    expect(find.textContaining('Cadastre pelo menos duas peças'), findsOneWidget);
    expect(find.byType(ClothingCard), findsNothing);
    expect(find.text('Evitar essa combinação'), findsNothing);
  });
}
