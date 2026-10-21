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
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart';
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;

Peca _peca(String id, String categoria) =>
    Peca(id: id, imagemUrl: '/uploads/$id.png', categoria: categoria);

class _PecaServiceVazio extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [];
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
    expect(find.text('Looks'), findsOneWidget);
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
    // Continua na tela de montagem (não voltou para "Looks"), com o nome
    // já digitado preservado.
    expect(find.text('Looks'), findsNothing);
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
}
