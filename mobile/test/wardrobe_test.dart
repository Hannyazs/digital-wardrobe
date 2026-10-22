// Testes da listagem do armário agrupada por categoria (E2.F1.1).
// Mesmo padrão dos demais: PecaService falso, nunca bate numa API real.
// `agruparPorCategoria` é testada isoladamente (função pura); os estados
// de carregamento/vazio/erro/com dados da tela são cobertos com widget
// tests. Ver docs/PBIs/E2-F1-listagem-do-armario/E2.F1.1-listagem-agrupada-por-categoria.md.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guarda_roupa_app/core/constants/peca_opcoes.dart' show gavetasDoArmario;
import 'package:guarda_roupa_app/models/look.dart';
import 'package:guarda_roupa_app/models/peca.dart';
import 'support/look_service_sem_historico.dart';
import 'package:guarda_roupa_app/services/peca_service.dart';
import 'package:guarda_roupa_app/views/home/home_shell.dart';
import 'package:guarda_roupa_app/views/looks/montar_look_controller.dart' show lookServiceProvider;
import 'package:guarda_roupa_app/views/upload/upload_controller.dart' show pecaServiceProvider;
import 'package:guarda_roupa_app/views/wardrobe/wardrobe_controller.dart';
import 'package:guarda_roupa_app/views/wardrobe/wardrobe_view.dart';
import 'package:guarda_roupa_app/views/suggestions/suggestions_controller.dart' show sugestaoServiceProvider;
import 'support/sugestao_service_sem_look_do_dia.dart';

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

class _PecaServiceGavetas extends PecaService {
  @override
  Future<List<Peca>> listarPecas() async => [
        _peca('1', 'Camisetas', corPrincipal: 'Azul'),
        _peca('2', 'Camisetas', corPrincipal: 'Preto'),
        _peca('3', 'Camisas', corPrincipal: 'Azul'),
        _peca('4', 'Calças', corPrincipal: 'Preto'),
      ];
}

Future<void> _abrirFiltros(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Filtros'));
  await tester.pumpAndSettle();
}

/// Fecha o painel pelo botão "Ver N peças".
Future<void> _fecharFiltros(WidgetTester tester) async {
  await tester.tap(find.textContaining(RegExp(r'^Ver \d+ peças?$')));
  await tester.pumpAndSettle();
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

  group('filtrarPecas (filtros múltiplos)', () {
    final pecas = [
      _peca('1', 'Camisetas', corPrincipal: 'Azul', estacao: 'Verão', ocasiao: 'Trabalho'),
      _peca('2', 'Calças', corPrincipal: 'Preto', estacao: 'Inverno', ocasiao: 'Faculdade'),
      _peca('3', 'Sapatos', corPrincipal: 'Azul', estacao: 'Inverno', ocasiao: 'Festa'),
      _peca('4', 'Casacos', corPrincipal: 'Bege', estacao: 'Todas as estações'),
    ];
    List<String> ids(FiltroPecas f) => filtrarPecas(pecas, f).map((p) => p.id).toList();

    test('filtro vazio não restringe nada', () {
      expect(ids(const FiltroPecas()), ['1', '2', '3', '4']);
    });

    test('um valor numa dimensão retorna só as peças correspondentes', () {
      expect(ids(const FiltroPecas(cores: {'Azul'})), ['1', '3']);
    });

    test('vários valores na mesma dimensão somam (OU)', () {
      expect(ids(const FiltroPecas(cores: {'Azul', 'Preto'})), ['1', '2', '3']);
      expect(ids(const FiltroPecas(ocasioes: {'Trabalho', 'Festa'})), ['1', '3']);
    });

    test('dimensões diferentes se combinam (E)', () {
      expect(ids(const FiltroPecas(cores: {'Azul'}, estacoes: {'Inverno'})), ['3']);
      expect(
        ids(const FiltroPecas(cores: {'Azul', 'Preto'}, ocasioes: {'Faculdade'})),
        ['2'],
      );
    });

    test('"Todas as estações" aparece em qualquer estação filtrada', () {
      expect(ids(const FiltroPecas(estacoes: {'Verão'})), ['1', '4']);
      expect(ids(const FiltroPecas(estacoes: {'Todas as estações'})), ['4']);
    });

    test('combinação sem correspondência retorna lista vazia', () {
      expect(ids(const FiltroPecas(cores: {'Preto'}, estacoes: {'Verão'})), isEmpty);
    });

    test('alternar marca e desmarca sem apagar as outras dimensões', () {
      final f = const FiltroPecas()
          .alternarCor('Azul')
          .alternarEstacao('Inverno')
          .alternarCor('Preto')
          .alternarOcasiao('Festa')
          .alternarCor('Azul');
      expect(f.cores, {'Preto'});
      expect(f.estacoes, {'Inverno'});
      expect(f.ocasioes, {'Festa'});
      expect(f.quantidade, 3);
    });

    test('opções vêm só das peças, na ordem das listas fixas; marcadas sempre aparecem', () {
      expect(coresDisponiveis(pecas), ['Preto', 'Bege', 'Azul']);
      expect(estacoesDisponiveis(pecas), ['Verão', 'Inverno', 'Todas as estações']);
      expect(ocasioesDisponiveis(pecas), ['Trabalho', 'Faculdade', 'Festa']);
      expect(ocasioesDisponiveis(pecas, {'Praia'}), ['Trabalho', 'Faculdade', 'Festa', 'Praia']);
    });
  });

  group('gavetas', () {
    test('agrupa em gavetas na ordem fixa, com "Outras" por último', () {
      final grupos = agruparPorGaveta([
        _peca('1', 'Sapatos'),
        _peca('2', 'Camisas'),
        _peca('3', 'Bonés'),
        _peca('4', 'Camisetas'),
        _peca('5', 'Saias'),
      ]);
      expect(grupos.keys.map((g) => g.nome).toList(),
          ['Partes de cima', 'Partes de baixo', 'Sapatos', 'Outras']);
      expect(grupos[gavetasDoArmario.first]!.map((p) => p.id).toList(), ['2', '4']);
    });

    test('gaveta com várias categorias tem uma seção por categoria', () {
      final secoes = secoesDaGaveta(gavetasDoArmario.first, [
        _peca('1', 'Camisas'),
        _peca('2', 'Camisetas'),
        _peca('3', 'Calças'),
      ]);
      expect(secoes.keys.toList(), ['Camisetas', 'Camisas']);
    });

    test('gaveta de uma categoria tem uma seção por subcategoria', () {
      final vestidos = gavetasDoArmario.firstWhere((g) => g.nome == 'Vestidos');
      Peca vestido(String id, String? sub) =>
          Peca(id: id, imagemUrl: '/$id.png', categoria: 'Vestidos', subcategoria: sub);

      expect(secoesDaGaveta(vestidos, [vestido('1', null)]).keys.toList(), ['Vestidos']);
      final secoes = secoesDaGaveta(vestidos, [
        vestido('1', 'midi'),
        vestido('2', null),
        vestido('3', 'Longo'),
        vestido('4', ' Longo '),
      ]);
      expect(secoes.keys.toList(), ['Longo', 'midi', 'Sem subcategoria']);
      expect(secoes['Longo']!.map((p) => p.id).toList(), ['3', '4']);
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

    expect(find.text('Partes de cima (1)'), findsOneWidget);
    expect(find.text('Outras (1)'), findsOneWidget);
  });

  testWidgets('Carrossel com poucas peças ganha espaços vazios no fim', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComDados())],
        child: const MaterialApp(home: WardrobeView()),
      ),
    );
    await tester.pumpAndSettle();

    // Uma peça em cada gaveta: cada carrossel tem pelo menos um espaço vazio.
    expect(find.byKey(const ValueKey('carrossel-espaco-vazio')), findsAtLeastNWidgets(2));
  });

  testWidgets('Tocar no nome da gaveta abre as subcategorias com as peças', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceGavetas())],
        child: const MaterialApp(home: WardrobeView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partes de cima (3)'), findsOneWidget);
    await tester.tap(find.text('Partes de cima (3)'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Partes de cima'), findsOneWidget);
    expect(find.text('Camisetas (2)'), findsOneWidget);
    expect(find.text('Camisas (1)'), findsOneWidget);
    expect(find.text('Calças (1)'), findsNothing);
  });

  testWidgets('Filtro do armário vale dentro da gaveta e continua ao voltar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceGavetas())],
        child: const MaterialApp(home: WardrobeView()),
      ),
    );
    await tester.pumpAndSettle();

    await _abrirFiltros(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Azul'));
    await _fecharFiltros(tester);
    expect(find.text('Partes de cima (2)'), findsOneWidget);

    await tester.tap(find.text('Partes de cima (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Camisetas (1)'), findsOneWidget);
    expect(find.text('Camisas (1)'), findsOneWidget);
    expect(find.text('2 peças de 3'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Partes de cima (2)'), findsOneWidget);
  });

  testWidgets('Aba "Looks" do armário mostra os looks salvos', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceGavetas()),
          lookServiceProvider.overrideWithValue(_LookServiceVazio()),
        ],
        child: const MaterialApp(home: WardrobeView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Looks'));
    await tester.pumpAndSettle();

    expect(find.text('Você ainda não tem nenhum look salvo'), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo), findsNothing); // FAB de peça só na aba Peças

    await tester.tap(find.text('Peças'));
    await tester.pumpAndSettle();
    expect(find.text('Partes de cima (3)'), findsOneWidget);
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

    expect(find.text('Partes de cima (1)'), findsOneWidget);
    expect(find.text('Partes de baixo (1)'), findsOneWidget);
    // Filtros escondidos até abrir o painel.
    expect(find.byType(FilterChip), findsNothing);

    await _abrirFiltros(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Azul'));
    await tester.pumpAndSettle();
    expect(find.text('Ver 2 peças'), findsOneWidget);
    await _fecharFiltros(tester);

    expect(find.text('Partes de cima (1)'), findsOneWidget);
    expect(find.text('Partes de baixo (1)'), findsNothing);
    expect(find.text('2 peças de 3'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Sapatos (1)'),
      find.byKey(const Key('armario-lista-categorias')),
      const Offset(0, -100),
    );
    expect(find.text('Sapatos (1)'), findsOneWidget);
  });

  testWidgets('Dois valores da mesma dimensão e de outra combinam sem se apagar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComVariedade())],
        child: const MaterialApp(home: WardrobeView()),
      ),
    );
    await tester.pumpAndSettle();

    await _abrirFiltros(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Azul'));
    await tester.tap(find.widgetWithText(FilterChip, 'Preto'));
    await tester.pumpAndSettle();
    expect(find.text('Ver 3 peças'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Inverno'));
    await tester.pumpAndSettle();
    expect(find.text('Ver 2 peças'), findsOneWidget);
    for (final chip in ['Azul', 'Preto', 'Inverno']) {
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, chip)).selected, isTrue);
    }
    await _fecharFiltros(tester);

    expect(find.text('Partes de cima (1)'), findsNothing); // Camiseta é de Verão
    expect(find.text('Partes de baixo (1)'), findsOneWidget);
    // Selo no botão: 3 valores marcados.
    expect(find.descendant(of: find.byType(Badge), matching: find.text('3')), findsOneWidget);
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

    await _abrirFiltros(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Preto'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Verão'));
    await tester.pumpAndSettle();
    expect(find.text('Ver 0 peças'), findsOneWidget);
    await _fecharFiltros(tester);

    expect(find.text('Nenhuma peça encontrada com esses filtros'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Limpar filtros').first);
    await tester.pumpAndSettle();

    expect(find.text('Partes de cima (1)'), findsOneWidget);
    expect(find.text('Partes de baixo (1)'), findsOneWidget);
  });

  testWidgets('"Limpar tudo" no painel desmarca todos os filtros', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pecaServiceProvider.overrideWithValue(_PecaServiceComVariedade())],
        child: const MaterialApp(home: WardrobeView()),
      ),
    );
    await tester.pumpAndSettle();

    await _abrirFiltros(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Preto'));
    await tester.tap(find.widgetWithText(FilterChip, 'Festa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar tudo'));
    await tester.pumpAndSettle();

    expect(find.text('Ver 3 peças'), findsOneWidget);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Preto')).selected, isFalse);
  });

  testWidgets('Navega pelas 5 abas da barra inferior (redesign visual, Etapa 4)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pecaServiceProvider.overrideWithValue(_PecaServiceVazio()),
          lookServiceProvider.overrideWithValue(_LookServiceVazio()),
          sugestaoServiceProvider.overrideWithValue(SugestaoServiceSemLookDoDia()),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();

    // Aba inicial: Casa.
    expect(find.text('Welcome!'), findsOneWidget);

    // Calendário de looks usados fica na Casa.
    expect(find.text('Calendário de looks'), findsOneWidget);

    await tester.tap(find.text('Armário'));
    await tester.pumpAndSettle();
    expect(find.text('Meu Guarda-Roupa'), findsOneWidget);

    // A aba "Looks" é só a montagem; os looks salvos ficam no Armário.
    // (`.last`: o seletor "Peças | Looks" do Armário também tem um "Looks".)
    await tester.tap(find.text('Looks').last);
    await tester.pumpAndSettle();
    // Armário vazio neste teste (`_PecaServiceVazio`) — MontarLookView
    // mostra a orientação pra cadastrar peça primeiro, não a grade.
    expect(find.text('Cadastre uma peça antes de montar um look'), findsOneWidget);

    await tester.tap(find.text('Sugestões'));
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
