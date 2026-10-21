// Testes da listagem do armário agrupada por categoria (E2.F1.1).
// Mesmo padrão dos demais: PecaService falso, nunca bate numa API real.
// `agruparPorCategoria` é testada isoladamente (função pura); os estados
// de carregamento/vazio/erro/com dados da tela são cobertos com widget
// tests. Ver docs/PBIs/E2-F1-listagem-do-armario/E2.F1.1-listagem-agrupada-por-categoria.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'support/look_service_sem_historico.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/home/home_shell.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;
import 'package:guarda_roupa_app/views/wardrobe/wardrobe_controller.dart';
import 'package:guarda_roupa_app/views/wardrobe/wardrobe_view.dart';

class _LookServiceVazio extends LookServiceSemHistorico {
  @override
  Future<List<Look>> listarLooks() async => [];
}

Peca _peca(
  String id,
  String categoria, {
  String? corPrincipal,
  String? estacao,
  String? ocasiao,
}) =>
    Peca(
      id: id,
      imagemUrl: '/uploads/$id.png',
      categoria: categoria,
      corPrincipal: corPrincipal,
      estacao: estacao,
      ocasioes: ocasiao == null ? const [] : [ocasiao],
    );

class _PecaServiceLento extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return [];
  }
}

class _PecaServiceVazio extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [];
}

class _PecaServiceComDados extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [
        _peca('1', 'Camisetas'),
        _peca('2', 'Outra categoria qualquer'),
      ];
}

class _PecaServiceComVariedade extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [
        _peca('1', 'Camisetas', corPrincipal: 'Azul', estacao: 'Verão', ocasiao: 'Trabalho'),
        _peca('2', 'Calças', corPrincipal: 'Preto', estacao: 'Inverno', ocasiao: 'Faculdade'),
        _peca('3', 'Sapatos', corPrincipal: 'Azul', estacao: 'Inverno', ocasiao: 'Festa'),
      ];
}

class _PecaServiceComErro extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async {
    throw DioException(
      requestOptions: RequestOptions(path: '/pecas'),
      type: DioExceptionType.connectionError,
    );
  }
}

void main() {
  group('agruparPorCategoria', () {
    test('agrupa na ordem fixa de categorias', () {
      final pecas = [
        _peca('1', 'Sapatos'),
        _peca('2', 'Camisetas'),
        _peca('3', 'Camisetas'),
      ];

      final grupos = agruparPorCategoria(pecas);

      expect(grupos.keys.toList(), ['Camisetas', 'Sapatos']);
      expect(grupos['Camisetas']!.length, 2);
      expect(grupos['Sapatos']!.length, 1);
    });

    test('categoria fora da lista fixa cai em "Outras", ao final', () {
      final pecas = [_peca('1', 'Camisetas'), _peca('2', 'Bonés')];

      final grupos = agruparPorCategoria(pecas);

      expect(grupos.keys.toList(), ['Camisetas', 'Outras']);
      expect(grupos['Outras']!.single.id, '2');
    });

    test('lista vazia produz mapa vazio', () {
      expect(agruparPorCategoria([]), isEmpty);
    });
  });

  group('filtrarPecas (E2.F2.1)', () {
    final pecas = [
      _peca('1', 'Camisetas', corPrincipal: 'Azul', estacao: 'Verão', ocasiao: 'Trabalho'),
      _peca('2', 'Calças', corPrincipal: 'Preto', estacao: 'Inverno', ocasiao: 'Faculdade'),
      _peca('3', 'Sapatos', corPrincipal: 'Azul', estacao: 'Inverno', ocasiao: 'Festa'),
    ];

    test('filtro vazio não restringe nada', () {
      expect(filtrarPecas(pecas, const FiltroArmario()).length, 3);
    });

    test('filtro de uma dimensão retorna só as peças correspondentes', () {
      final resultado = filtrarPecas(pecas, const FiltroArmario(corPrincipal: 'Azul'));
      expect(resultado.map((p) => p.id).toList(), ['1', '3']);
    });

    test('filtros combinados usam E lógico, não OU', () {
      final resultado = filtrarPecas(
        pecas,
        const FiltroArmario(corPrincipal: 'Azul', estacao: 'Inverno'),
      );
      expect(resultado.map((p) => p.id).toList(), ['3']);
    });

    test('combinação sem correspondência retorna lista vazia', () {
      final resultado = filtrarPecas(
        pecas,
        const FiltroArmario(corPrincipal: 'Preto', estacao: 'Verão'),
      );
      expect(resultado, isEmpty);
    });

    test('coresDisponiveis e estacoesDisponiveis retornam valores distintos ordenados', () {
      expect(coresDisponiveis(pecas), ['Azul', 'Preto']);
      expect(estacoesDisponiveis(pecas), ['Inverno', 'Verão']);
    });
  });

  testWidgets('Mostra indicador de carregamento enquanto busca as peças', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceLento())],
        child: const MaterialApp(home: WardrobeView()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Deixa o timer de 1s do serviço falso terminar antes do teste acabar
    // — senão o `flutter test` acusa timer pendente.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Mostra estado vazio quando não há peças', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceVazio())],
        child: const MaterialApp(home: WardrobeView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seu armário está vazio'), findsOneWidget);
    expect(find.text('Toque em + para adicionar sua primeira peça'), findsOneWidget);
  });

  testWidgets('Mostra peças agrupadas por categoria, incluindo grupo Outras', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComDados())],
        child: const MaterialApp(home: WardrobeView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Camisetas (1)'), findsOneWidget);
    expect(find.text('Outras (1)'), findsOneWidget);
  });

  testWidgets('Mostra erro com "Tentar novamente" quando a busca falha', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComErro())],
        child: const MaterialApp(home: WardrobeView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com o servidor. Verifique sua internet e tente novamente.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    // Mesmo serviço falso continua falhando — não deve travar, só repetir o erro.
    expect(
      find.text('Sem conexão com o servidor. Verifique sua internet e tente novamente.'),
      findsOneWidget,
    );
  });

  testWidgets('Aplica filtro de cor na tela e restringe a lista exibida', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComVariedade())],
        child: const MaterialApp(home: WardrobeView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Camisetas (1)'), findsOneWidget);
    expect(find.text('Calças (1)'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Azul'));
    await tester.pumpAndSettle();

    expect(find.text('Camisetas (1)'), findsOneWidget);
    expect(find.text('Calças (1)'), findsNothing);
    await tester.dragUntilVisible(
      find.text('Sapatos (1)'),
      find.byKey(const Key('armario-lista-categorias')),
      const Offset(0, -100),
    );
    expect(find.text('Sapatos (1)'), findsOneWidget);
  });

  testWidgets('Combinação de filtros sem correspondência mostra vazio-por-filtro e limpa', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComVariedade())],
        child: const MaterialApp(home: WardrobeView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Preto'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Verão'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma peça encontrada com esses filtros'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Limpar filtros').first);
    await tester.pumpAndSettle();

    expect(find.text('Camisetas (1)'), findsOneWidget);
    expect(find.text('Calças (1)'), findsOneWidget);
  });

  testWidgets('Navega pelas 5 abas da barra inferior (redesign visual, Etapa 4)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceVazio()),
          lookServiceProvider.overrideWithValue(_LookServiceVazio()),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();

    // Aba inicial: Casa.
    expect(find.text('Welcome!'), findsOneWidget);

    await tester.tap(find.text('Armário'));
    await tester.pumpAndSettle();
    expect(find.text('Meu Guarda-Roupa'), findsOneWidget);

    // "Looks" agora é a tela de montagem (Criação de Looks) — "Meus looks"
    // salvos virou um botão dentro dela, não uma aba própria (ver
    // docs/redesign-visual.md).
    await tester.tap(find.text('Looks'));
    await tester.pumpAndSettle();
    // Armário vazio neste teste (`_PecaServiceVazio`) — MontarLookView
    // mostra a orientação pra cadastrar peça primeiro, não a grade.
    expect(find.text('Cadastre uma peça antes de montar um look'), findsOneWidget);

    await tester.tap(find.text('IA'));
    await tester.pumpAndSettle();
    expect(find.text('Your suggestions'), findsOneWidget);

    await tester.tap(find.text('Referências'));
    await tester.pumpAndSettle();
    expect(find.text('Find your inspiration'), findsOneWidget);

    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome!'), findsOneWidget);
  });
}
