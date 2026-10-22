// Testes da tela de montagem manual de look (E3.F1.2).
// Mesmo padrão de peca_form_test.dart: PecaService/LookService falsos,
// nunca bate numa API real. Navega a partir de LooksView (FAB "Montar
// look"), como no fluxo real do app.
// Ver docs/PBIs/E3-F1-montagem-manual-looks/E3.F1.2-tela-de-montagem-do-look.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/core/widgets/clothing_card.dart';
import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'support/look_service_sem_historico.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/looks/looks_view.dart';
import 'package:guarda_roupa_app/services/look_service.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_view.dart';
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;

Peca _peca(String id, String categoria) =>
    Peca(id: id, imagemUrl: '/uploads/$id.png', categoria: categoria);

class _PecaServiceVazio extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [];
}

class _PecaServiceColorido extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [
        Peca(id: '1', imagemUrl: '/1.png', categoria: 'Camisetas', corPrincipal: 'Azul'),
        Peca(id: '2', imagemUrl: '/2.png', categoria: 'Camisetas', corPrincipal: 'Preto'),
        Peca(
          id: '3',
          imagemUrl: '/3.png',
          categoria: 'Calças',
          corPrincipal: 'Preto',
          estacao: 'Inverno',
        ),
      ];
}

class _PecaServiceComDuasPecas extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [
        _peca('1', 'Camisetas'),
        _peca('2', 'Calças'),
      ];
}

// `listarLooks` também é sobrescrito nas duas classes abaixo porque
// `LooksView` (E3.F1.3) busca a lista ao montar e de novo ao voltar da
// montagem — sem isso, bateria numa API real dentro do teste.
class _LookServiceVazio extends LookServiceSemHistorico {
  @override
  Future<List<Look>> listarLooks() async => [];
}

class _LookServiceComSucesso extends LookServiceSemHistorico {
  final criados = <(String, List<String>)>[];

  @override
  Future<List<Look>> listarLooks() async => [];

  @override
  Future<Look> criarLook({
    required String nome,
    required List<String> pecaIds,
    List<String> ocasioes = const [],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    criados.add((nome, ocasioes));
    return Look(
      id: 'look-1',
      nome: nome,
      criadoEm: DateTime.now(),
      pecas: pecaIds.map((id) => _peca(id, 'Camisetas')).toList(),
      ocasioes: ocasioes,
    );
  }
}

class _LookServiceComErro extends LookServiceSemHistorico {
  @override
  Future<List<Look>> listarLooks() async => [];

  @override
  Future<Look> criarLook({
    required String nome,
    required List<String> pecaIds,
    List<String> ocasioes = const [],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw DioException(
      requestOptions: RequestOptions(path: '/looks'),
      type: DioExceptionType.connectionError,
    );
  }
}

Future<void> _abrirMontarLook(WidgetTester tester) async {
  await tester.tap(find.text('Montar look'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Armário vazio orienta a cadastrar uma peça, sem abrir grade', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceVazio()),
          lookServiceProvider.overrideWithValue(_LookServiceVazio()),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pumpAndSettle();

    await _abrirMontarLook(tester);

    expect(find.text('Cadastre uma peça antes de montar um look'), findsOneWidget);
    expect(find.text('Cadastrar peça'), findsOneWidget);
    expect(find.text('Salvar look'), findsNothing);
  });

  testWidgets('Sem nome ou sem seleção, "Salvar look" permanece desabilitado', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceComDuasPecas()),
          lookServiceProvider.overrideWithValue(_LookServiceVazio()),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pumpAndSettle();

    await _abrirMontarLook(tester);

    ElevatedButton salvarButton() =>
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Salvar look'));

    expect(salvarButton().onPressed, isNull);

    // Só nome, sem peça selecionada: ainda desabilitado.
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome do look *'), 'Look de sexta');
    await tester.pump();
    expect(salvarButton().onPressed, isNull);
  });

  testWidgets('Nome e peça selecionada salvam o look e voltam para Looks', (
    WidgetTester tester,
  ) async {
    final servico = _LookServiceComSucesso();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceComDuasPecas()),
          lookServiceProvider.overrideWithValue(servico),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pumpAndSettle();

    await _abrirMontarLook(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome do look *'), 'Look de sexta');
    await tester.tap(find.byType(ClothingCard).first);
    await tester.pump();

    final salvarButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Salvar look'),
    );
    expect(salvarButton.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar look'));
    await tester.pumpAndSettle();

    expect(find.text('Look "Look de sexta" salvo.'), findsOneWidget);
    // Voltou para a lista de looks salvos (aberta por cima, então "volta").
    expect(find.text('Salvar look'), findsNothing);
    expect(find.text('Montar look'), findsOneWidget);
  });

  testWidgets('Falha no envio mostra mensagem de erro e mantém nome e seleção', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceComDuasPecas()),
          lookServiceProvider.overrideWithValue(_LookServiceComErro()),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pumpAndSettle();

    await _abrirMontarLook(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome do look *'), 'Look de sexta');
    await tester.tap(find.byType(ClothingCard).first);
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar look'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Verifique sua internet e tente novamente.'),
      findsOneWidget,
    );
    // Continua na tela de montagem (não voltou para os looks salvos), com o
    // nome já digitado preservado.
    expect(find.text('Salvar look'), findsOneWidget);
    expect(find.text('Look de sexta'), findsOneWidget);
  });

  testWidgets('Ocasiões escolhidas são enviadas (várias, em ordem canônica); sem escolha, vai vazio', (
    WidgetTester tester,
  ) async {
    final servico = _LookServiceComSucesso();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceComDuasPecas()),
          lookServiceProvider.overrideWithValue(servico),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pumpAndSettle();

    /// [marcar] são tocadas na ordem dada; [desmarcar] depois (toque no chip já marcado).
    Future<void> montarESalvar(
      String nome, {
      List<String> marcar = const [],
      List<String> desmarcar = const [],
    }) async {
      await _abrirMontarLook(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Nome do look *'), nome);
      await tester.tap(find.byType(ClothingCard).first);
      await tester.pump();
      for (final ocasiao in [...marcar, ...desmarcar]) {
        await tester.tap(find.widgetWithText(FilterChip, ocasiao));
        await tester.pump();
      }
      await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar look'));
      await tester.pumpAndSettle();
    }

    // Faculdade antes de Trabalho: a ordem enviada é a de `ocasioesFixas`.
    await montarESalvar('Com duas', marcar: ['Faculdade', 'Trabalho']);
    await montarESalvar('Sem ocasião');
    await montarESalvar('Desmarcada', marcar: ['Festa'], desmarcar: ['Festa']);
    await montarESalvar('Desmarca uma', marcar: ['Casual', 'Festa'], desmarcar: ['Casual']);

    // Texto, porque registros Dart comparam as listas por identidade.
    expect(servico.criados.map((c) => '${c.$1}: ${c.$2}'), [
      'Com duas: [Trabalho, Faculdade]',
      'Sem ocasião: []',
      'Desmarcada: []',
      'Desmarca uma: [Festa]',
    ]);
  });

  testWidgets('Falha no envio preserva a ocasião escolhida', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceComDuasPecas()),
          lookServiceProvider.overrideWithValue(_LookServiceComErro()),
        ],
        child: const MaterialApp(home: LooksView()),
      ),
    );
    await tester.pumpAndSettle();
    await _abrirMontarLook(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome do look *'), 'Look de sexta');
    await tester.tap(find.byType(ClothingCard).first);
    await tester.tap(find.widgetWithText(FilterChip, 'Festa'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar look'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Festa')).selected,
      isTrue,
    );
  });

  // --- Reorganização da interface: carrosséis com filtros na montagem ---

  Future<void> abrirMontagemComoAba(WidgetTester tester, LookService servico) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceColorido()),
          lookServiceProvider.overrideWithValue(servico),
        ],
        child: const MaterialApp(home: MontarLookView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Filtros da montagem combinam e não perdem a peça já selecionada', (tester) async {
    await abrirMontagemComoAba(tester, _LookServiceComSucesso());

    expect(find.text('Camisetas'), findsOneWidget);
    expect(find.text('Calças'), findsOneWidget);
    // Seleciona a camiseta azul (primeiro card).
    await tester.tap(find.byType(ClothingCard).first);
    await tester.pump();
    expect(find.text('1 peça selecionada'), findsOneWidget);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Preto'));
    await tester.tap(find.widgetWithText(FilterChip, 'Inverno'));
    await tester.pumpAndSettle();
    expect(find.text('Ver 1 peça'), findsOneWidget);
    await tester.tap(find.text('Ver 1 peça'));
    await tester.pumpAndSettle();

    // Só a calça preta de inverno aparece; a camiseta azul continua escolhida.
    expect(find.text('Camisetas'), findsNothing);
    expect(find.text('Calças'), findsOneWidget);
    expect(find.text('1 peça selecionada'), findsOneWidget);

    await tester.tap(find.byType(ClothingCard).first);
    await tester.pump();
    expect(find.text('2 peças selecionadas'), findsOneWidget);
  });

  testWidgets('Filtro sem resultado na montagem oferece limpar', (tester) async {
    await abrirMontagemComoAba(tester, _LookServiceComSucesso());

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Azul'));
    await tester.tap(find.widgetWithText(FilterChip, 'Inverno'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver 0 peças'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma peça encontrada com esses filtros'), findsOneWidget);
    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();
    expect(find.byType(ClothingCard), findsNWidgets(3));
  });

  testWidgets('Salvar pela aba (sem tela por baixo) limpa a montagem em vez de voltar', (
    tester,
  ) async {
    final servico = _LookServiceComSucesso();
    await abrirMontagemComoAba(tester, servico);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome do look *'), 'Look de sexta');
    await tester.tap(find.byType(ClothingCard).first);
    await tester.tap(find.widgetWithText(FilterChip, 'Festa'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Salvar look'));
    await tester.pumpAndSettle();

    expect(servico.criados.single.$1, 'Look de sexta');
    expect(find.text('Look "Look de sexta" salvo.'), findsOneWidget);
    // Continua na montagem, pronta para o próximo look.
    expect(find.text('Monte seu look'), findsOneWidget);
    expect(find.text('Toque nas peças para escolher'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Look de sexta'), findsNothing);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Festa')).selected, isFalse);
  });

  testWidgets('A montagem não tem mais atalho para os looks salvos', (tester) async {
    await abrirMontagemComoAba(tester, _LookServiceComSucesso());
    expect(find.byTooltip('Meus looks'), findsNothing);
  });
}
